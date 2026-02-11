/// Authentication service for user registration, login, and token management.
///
/// Handles JWT token storage and refresh.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../database/app_database.dart';

/// Storage keys for tokens
class AuthStorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
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
class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage;
  final String _baseUrl;
  final AppDatabase _database;

  AuthUser? _currentUser;

  AuthService({
    FlutterSecureStorage? storage,
    String? baseUrl,
    AppDatabase? database,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _baseUrl = baseUrl ?? ApiConfig.apiUrl,
       _database = database ?? AppDatabase();

  /// Get current cached user
  AuthUser? get currentUser => _currentUser;

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AuthStorageKeys.accessToken);
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AuthStorageKeys.refreshToken);
  }

  /// Register a new user
  Future<AuthUser> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final user = AuthUser.fromJson(jsonDecode(response.body));
      return user;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  /// Login with email and password
  Future<AuthUser> login(String email, String password) async {
    // Get tokens
    final tokenResponse = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (tokenResponse.statusCode != 200) {
      final error = jsonDecode(tokenResponse.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }

    final tokens = AuthTokens.fromJson(jsonDecode(tokenResponse.body));

    // Store tokens
    await _storage.write(
      key: AuthStorageKeys.accessToken,
      value: tokens.accessToken,
    );
    await _storage.write(
      key: AuthStorageKeys.refreshToken,
      value: tokens.refreshToken,
    );

    // Get user info
    final userResponse = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${tokens.accessToken}',
      },
    );

    if (userResponse.statusCode == 200) {
      final user = AuthUser.fromJson(jsonDecode(userResponse.body));
      _currentUser = user;
      notifyListeners();

      // Store user info
      await _storage.write(key: AuthStorageKeys.userId, value: user.id);
      await _storage.write(key: AuthStorageKeys.userEmail, value: user.email);

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

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final tokens = AuthTokens.fromJson(jsonDecode(response.body));
        await _storage.write(
          key: AuthStorageKeys.accessToken,
          value: tokens.accessToken,
        );
        await _storage.write(
          key: AuthStorageKeys.refreshToken,
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
  Future<void> logout() async {
    _currentUser = null;
    await _storage.delete(key: AuthStorageKeys.accessToken);
    await _storage.delete(key: AuthStorageKeys.refreshToken);
    await _storage.delete(key: AuthStorageKeys.userId);
    await _storage.delete(key: AuthStorageKeys.userEmail);
    await _database.clearAllData();
    notifyListeners();
  }

  /// Load user from storage (for app startup)
  Future<AuthUser?> loadStoredUser() async {
    final userId = await _storage.read(key: AuthStorageKeys.userId);
    final userEmail = await _storage.read(key: AuthStorageKeys.userEmail);
    final token = await getAccessToken();

    if (userId != null && userEmail != null && token != null) {
      // Validate token logic
      // Ideally we should call an endpoint to verify the token is still valid.
      // For now allowing offline access if we have a token.
      // If online, we could try to refresh it if it's expired or if an API call fails with 401 later.

      _currentUser = AuthUser(
        id: userId,
        email: userEmail,
        createdAt: DateTime.now(),
      );

      // Attempt to refresh in background or validate session
      try {
        // This is a "silent" check/refresh.
        // If it fails, that's fine, we might be offline.
        // If we are online and token is bad, api calls will 401 and we handle that there.
        // But let's try to verify if we can.
        final isValid =
            await isLoggedIn(); // Checks if token exists, weak check.
        if (isValid) {
          // Try to fetch Fresh user data
          final userResponse = await http.get(
            Uri.parse('$_baseUrl/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (userResponse.statusCode == 200) {
            final user = AuthUser.fromJson(jsonDecode(userResponse.body));
            _currentUser = user; // Update with fresh data
            await _storage.write(key: AuthStorageKeys.userId, value: user.id);
            await _storage.write(
              key: AuthStorageKeys.userEmail,
              value: user.email,
            );
          } else if (userResponse.statusCode == 401) {
            // Token expired? Try refresh
            final refreshed = await refreshAccessToken();
            if (!refreshed) {
              // Failed to refresh, logout needed technically,
              // but maybe we let them stay in offline mode until they try an action?
              // The user mentioned "getting logged out" randomly.
              // If we aggressive logout here, that might be it.
              // Let's NOT clear data here unless we are sure.
            }
          }
        }
      } catch (e) {
        // Network error likely, ignore
      }

      return _currentUser;
    }

    return null;
  }
}
