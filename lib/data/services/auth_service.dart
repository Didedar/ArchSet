/// Authentication service for user registration, login, and token management.
///
/// Handles JWT token storage and refresh.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../database/app_database.dart';

/// Storage keys for tokens.
///
/// The app re-picks its backend (production vs. localhost) on every launch,
/// but a JWT minted by one backend is meaningless to the other — they sign
/// with different secrets and have different user databases. So every
/// per-account key is namespaced by [originSlug], keyed off the backend's
/// host+port, to stop a token (or cached identity) from one origin being
/// misread as valid for another.
class AuthStorageKeys {
  const AuthStorageKeys._();

  static const String _accessTokenStem = 'access_token';
  static const String _refreshTokenStem = 'refresh_token';
  static const String _userIdStem = 'user_id';
  static const String _userEmailStem = 'user_email';
  static const String _userCreatedAtStem = 'user_created_at';

  /// The one account that owns the app right now (absent => guest). NOT
  /// origin-scoped: it identifies the signed-in account regardless of which
  /// backend it happens to be talking to.
  static const String currentOwnerId = 'current_owner_id';

  /// Stable slug for a backend origin (host+port).
  static String originSlug(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final host = (uri == null || uri.host.isEmpty) ? 'local' : uri.host;
    final port = uri?.port ?? 0;
    return '${host}_$port'.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  }

  static String accessToken(String slug) => '${_accessTokenStem}_$slug';
  static String refreshToken(String slug) => '${_refreshTokenStem}_$slug';
  static String userId(String slug) => '${_userIdStem}_$slug';
  static String userEmail(String slug) => '${_userEmailStem}_$slug';
  static String userCreatedAt(String slug) => '${_userCreatedAtStem}_$slug';
}

/// User model for authentication
class AuthUser {
  final String id;
  final String email;
  final DateTime createdAt;

  AuthUser({required this.id, required this.email, required this.createdAt});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Authentication tokens
class AuthTokens {
  final String accessToken;
  final String refreshToken;

  AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

/// Authentication service
class AuthService implements AuthRepository {
  /// Ceiling on any auth request, so a hung socket can never stall the splash.
  static const Duration _requestTimeout = Duration(seconds: 15);

  final FlutterSecureStorage _storage;
  final String _baseUrl;
  final AppDatabase _database;

  /// One client for the lifetime of the service. The previous code used the
  /// top-level `http.post`/`http.get` helpers, each of which opens and closes
  /// its own client — a fresh TCP + TLS handshake on every single auth call.
  final http.Client _client;

  AuthUser? _currentUser;

  /// Slug for the backend this instance talks to, used to namespace every
  /// per-account storage key so tokens/identities from one backend origin
  /// are never read back as valid for another.
  late final String _originSlug = AuthStorageKeys.originSlug(_baseUrl);

  /// Broadcasts when a caller (e.g. an API client that just saw a 401 it
  /// couldn't recover from) decides the current session is no longer valid.
  /// Consumed later (B6) by SessionCubit's `sessionExpiredSignal`.
  final StreamController<void> _sessionExpired =
      StreamController<void>.broadcast();

  AuthService({
    required AppDatabase database,
    FlutterSecureStorage? storage,
    String? baseUrl,
    http.Client? client,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _baseUrl = baseUrl ?? ApiConfig.apiUrl,
       _database = database,
       _client = client ?? http.Client();

  /// Get current cached user
  @override
  AuthUser? get currentUser => _currentUser;

  /// Emits whenever [notifySessionExpired] is called.
  Stream<void> get onSessionExpired => _sessionExpired.stream;

  /// Signals that the current session is no longer valid.
  void notifySessionExpired() {
    if (!_sessionExpired.isClosed) _sessionExpired.add(null);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AuthStorageKeys.accessToken(_originSlug));
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AuthStorageKeys.refreshToken(_originSlug));
  }

  /// Register a new user
  @override
  Future<AuthUser> register(String email, String password) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 201) {
      final user = AuthUser.fromJson(jsonDecode(response.body));
      await _storage.write(key: AuthStorageKeys.currentOwnerId, value: user.id);
      return user;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  /// Login with email and password
  @override
  Future<AuthUser> login(String email, String password) async {
    // Get tokens
    final tokenResponse = await _client
        .post(
          Uri.parse('$_baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_requestTimeout);

    if (tokenResponse.statusCode != 200) {
      final error = jsonDecode(tokenResponse.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }

    final tokens = AuthTokens.fromJson(jsonDecode(tokenResponse.body));

    // Store tokens, namespaced to this backend's origin.
    await _storage.write(
      key: AuthStorageKeys.accessToken(_originSlug),
      value: tokens.accessToken,
    );
    await _storage.write(
      key: AuthStorageKeys.refreshToken(_originSlug),
      value: tokens.refreshToken,
    );

    // Get user info
    final userResponse = await _client
        .get(
          Uri.parse('$_baseUrl/auth/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${tokens.accessToken}',
          },
        )
        .timeout(_requestTimeout);

    if (userResponse.statusCode == 200) {
      final user = AuthUser.fromJson(jsonDecode(userResponse.body));
      await _persistUser(user);
      return user;
    } else {
      throw Exception('Failed to get user info');
    }
  }

  /// Refresh access token using refresh token
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final tokens = AuthTokens.fromJson(jsonDecode(response.body));
        await _storage.write(
          key: AuthStorageKeys.accessToken(_originSlug),
          value: tokens.accessToken,
        );
        await _storage.write(
          key: AuthStorageKeys.refreshToken(_originSlug),
          value: tokens.refreshToken,
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return false;
    }
  }

  /// Local sign-out. Clears ONLY the namespaced session + current owner id.
  /// The on-device diary (notes/folders/artifacts) is intentionally left
  /// untouched — logging out must not destroy the user's local data.
  @override
  Future<void> logout() async {
    _currentUser = null;
    await _clearNamespacedSession();
  }

  /// Load user from storage (for app startup).
  ///
  /// Fail-closed only against a server that actually answers. A stored
  /// identity is returned outright once its token is confirmed valid, either
  /// directly against `/auth/me` or via a successful refresh. If the token is
  /// actively rejected (401) and the refresh also fails, the session is dead,
  /// so the namespaced session is cleared and `null` is returned. If the
  /// server is merely unreachable (offline, 5xx), that's ambiguous — not
  /// proof the token is bad — so the token is left untouched and the last
  /// verified identity is served back from the local cache instead (`null`
  /// only if nothing was ever cached); a later online start still re-verifies
  /// it. Never touches the local diary.
  @override
  Future<AuthUser?> loadStoredUser() async {
    final token = await getAccessToken();
    if (token == null) return null;

    final me = await _getMe(token);
    switch (me) {
      case _MeOk(:final user):
        await _persistUser(user);
        return user;
      case _MeUnreachable():
        // "Couldn't verify" is not "verified and rejected". Returning null
        // here collapsed offline into guest: SessionCubit emitted
        // SessionGuest, CurrentOwnerHolder went null, and NotesRepository
        // filtered the user's own rows out -- an empty diary with no signal.
        // Keep the token AND the identity; the next successful contact
        // re-verifies, and a real 401 still logs out below.
        return _cachedUser();
      case _MeRejected():
        break; // try a refresh
    }

    final refreshed = await refreshAccessToken();
    if (refreshed) {
      final newToken = await getAccessToken();
      if (newToken != null) {
        final retry = await _getMe(newToken);
        if (retry is _MeOk) {
          await _persistUser(retry.user);
          return retry.user;
        }
      }
    }

    // Token was rejected and the refresh failed too: fail closed.
    await _clearNamespacedSession();
    _currentUser = null;
    return null;
  }

  /// Confirms a token against the backend. A 401 means the token is actively
  /// rejected; anything else short of a clean 200 (timeout, socket error,
  /// 5xx) is ambiguous and must never be treated as proof the token is bad.
  Future<_MeResult> _getMe(String token) async {
    try {
      final resp = await _client
          .get(
            Uri.parse('$_baseUrl/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout);

      if (resp.statusCode == 200) {
        return _MeOk(AuthUser.fromJson(jsonDecode(resp.body)));
      }
      if (resp.statusCode == 401) return const _MeRejected();
      return const _MeUnreachable(); // 5xx/other: ambiguous, don't destroy
    } catch (e) {
      return const _MeUnreachable(); // offline/network error: preserve token
    }
  }

  /// Caches a server-confirmed identity and persists it under this backend's
  /// namespaced keys, plus the un-namespaced `currentOwnerId`.
  Future<void> _persistUser(AuthUser user) async {
    _currentUser = user;
    await Future.wait([
      _storage.write(key: AuthStorageKeys.userId(_originSlug), value: user.id),
      _storage.write(
        key: AuthStorageKeys.userEmail(_originSlug),
        value: user.email,
      ),
      _storage.write(
        key: AuthStorageKeys.userCreatedAt(_originSlug),
        value: user.createdAt.toIso8601String(),
      ),
      _storage.write(key: AuthStorageKeys.currentOwnerId, value: user.id),
    ]);
  }

  /// The last verified identity for this backend origin, rebuilt from secure
  /// storage. Only used when the server could not be reached -- never to
  /// override an answer the server actually gave.
  Future<AuthUser?> _cachedUser() async {
    final id = await _storage.read(key: AuthStorageKeys.userId(_originSlug));
    final email = await _storage.read(
      key: AuthStorageKeys.userEmail(_originSlug),
    );
    if (id == null || email == null) return null;

    // Sessions stored before createdAt was persisted have no value here. The
    // app never reads createdAt, so epoch is a safe stand-in and is a better
    // outcome than forcing a field user to re-authenticate with no signal.
    final rawCreatedAt = await _storage.read(
      key: AuthStorageKeys.userCreatedAt(_originSlug),
    );
    final createdAt = rawCreatedAt == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.tryParse(rawCreatedAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);

    final user = AuthUser(id: id, email: email, createdAt: createdAt);
    _currentUser = user;
    return user;
  }

  /// Wipes every key this backend origin owns, plus `currentOwnerId`. Only
  /// called once a token is confirmed dead (401 + failed refresh) — never
  /// for a merely-unreachable server. Deliberately leaves the local diary
  /// untouched.
  Future<void> _clearNamespacedSession() async {
    await Future.wait([
      _storage.delete(key: AuthStorageKeys.accessToken(_originSlug)),
      _storage.delete(key: AuthStorageKeys.refreshToken(_originSlug)),
      _storage.delete(key: AuthStorageKeys.userId(_originSlug)),
      _storage.delete(key: AuthStorageKeys.userEmail(_originSlug)),
      _storage.delete(key: AuthStorageKeys.userCreatedAt(_originSlug)),
      _storage.delete(key: AuthStorageKeys.currentOwnerId),
    ]);
  }

  /// Releases the shared HTTP client.
  void dispose() {
    _client.close();
    _sessionExpired.close();
  }
}

/// Outcome of confirming a token against `/auth/me`.
sealed class _MeResult {
  const _MeResult();
}

/// The token is valid; the server returned the current user.
final class _MeOk extends _MeResult {
  const _MeOk(this.user);
  final AuthUser user;
}

/// The token was actively rejected (401).
final class _MeRejected extends _MeResult {
  const _MeRejected();
}

/// The server couldn't be reached, or answered ambiguously (timeout, socket
/// error, 5xx). Not proof the token is bad.
final class _MeUnreachable extends _MeResult {
  const _MeUnreachable();
}
