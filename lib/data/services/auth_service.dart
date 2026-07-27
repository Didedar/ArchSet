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
      _currentUser = user;

      // Store user info, namespaced to this backend's origin.
      await _storage.write(
        key: AuthStorageKeys.userId(_originSlug),
        value: user.id,
      );
      await _storage.write(
        key: AuthStorageKeys.userEmail(_originSlug),
        value: user.email,
      );
      // The one account that owns the app right now. NOT origin-scoped: a
      // later task reads this to claim guest data on this device.
      await _storage.write(key: AuthStorageKeys.currentOwnerId, value: user.id);

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

  /// Logout and clear stored data
  @override
  Future<void> logout() async {
    _currentUser = null;
    await _storage.delete(key: AuthStorageKeys.accessToken(_originSlug));
    await _storage.delete(key: AuthStorageKeys.refreshToken(_originSlug));
    await _storage.delete(key: AuthStorageKeys.userId(_originSlug));
    await _storage.delete(key: AuthStorageKeys.userEmail(_originSlug));
    await _database.clearAllData();
  }

  /// Load user from storage (for app startup).
  ///
  /// This sits on the splash critical path, so it must not wait on the network.
  /// The three keychain reads run concurrently, and the server-side
  /// revalidation is fire-and-forget: the cached identity is returned
  /// immediately and refreshed in the background. Offline access is unaffected,
  /// and a stale token still surfaces as a 401 on the next real API call.
  @override
  Future<AuthUser?> loadStoredUser() async {
    final results = await Future.wait([
      _storage.read(key: AuthStorageKeys.userId(_originSlug)),
      _storage.read(key: AuthStorageKeys.userEmail(_originSlug)),
      getAccessToken(),
    ]);
    final userId = results[0];
    final userEmail = results[1];
    final token = results[2];

    if (userId == null || userEmail == null || token == null) return null;

    _currentUser = AuthUser(
      id: userId,
      email: userEmail,
      createdAt: DateTime.now(),
    );

    unawaited(_revalidateSession(token));

    return _currentUser;
  }

  /// Best-effort background refresh of the cached user. Never throws — a
  /// failure here just means we keep using the cached identity.
  Future<void> _revalidateSession(String token) async {
    try {
      final userResponse = await _client
          .get(
            Uri.parse('$_baseUrl/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_requestTimeout);

      if (userResponse.statusCode == 200) {
        final user = AuthUser.fromJson(jsonDecode(userResponse.body));
        _currentUser = user;
        await Future.wait([
          _storage.write(
            key: AuthStorageKeys.userId(_originSlug),
            value: user.id,
          ),
          _storage.write(
            key: AuthStorageKeys.userEmail(_originSlug),
            value: user.email,
          ),
        ]);
      } else if (userResponse.statusCode == 401) {
        // Token may just be expired. Refresh if we can; deliberately do NOT
        // clear stored credentials on failure, so a transient server or
        // network fault can't silently log the user out.
        await refreshAccessToken();
      }
    } catch (e) {
      debugPrint('Session revalidation skipped: $e');
    }
  }

  /// Releases the shared HTTP client.
  void dispose() {
    _client.close();
    _sessionExpired.close();
  }
}
