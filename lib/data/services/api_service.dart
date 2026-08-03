/// API client for communicating with the ArchSet backend.
///
/// Handles HTTP requests, authentication headers, and error handling.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// API configuration
class ApiConfig {
  static String _baseUrl =
      'https://archset-backend-production.up.railway.app'; // Production URL

  static const String productionUrl =
      'https://archset-backend-production.up.railway.app';

  /// A dev backend named explicitly at build time, e.g.
  /// `--dart-define=DEV_API_URL=http://192.168.1.42:8000`. Wins over the
  /// guesses below when it answers.
  static const String devApiUrl = String.fromEnvironment('DEV_API_URL');

  /// The machine running the backend, as seen from the phone over Wi-Fi:
  /// `--dart-define=DEV_API_HOST=192.168.1.42`. `scripts/dev.sh` fills this in
  /// automatically, which is what removes the manual step.
  static const String devApiHost = String.fromEnvironment('DEV_API_HOST');

  /// Picks the first backend that actually answers.
  ///
  /// Production is checked first; if it is unreachable or unhealthy, each dev
  /// [candidates] entry is tried in order. Falls back to production when
  /// nothing responds, because the app is offline-first and will retry --
  /// leaving it pointed at a laptop address that is not there would strand it.
  ///
  /// Sequential rather than concurrent on purpose: order expresses preference,
  /// and a race would hand the answer to whichever host was quickest rather
  /// than to the one meant to win.
  @visibleForTesting
  static Future<String> resolveBaseUrl({
    required http.Client client,
    required List<String> candidates,
  }) async {
    Future<bool> healthy(String origin) async {
      try {
        final response = await client
            .get(Uri.parse('$origin/health'))
            .timeout(const Duration(seconds: 3));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    if (await healthy(productionUrl)) return productionUrl;

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if (await healthy(candidate)) return candidate;
    }

    return productionUrl;
  }

  /// Dev backends to try, most specific first.
  ///
  /// `127.0.0.1` only reaches the developer's machine while an
  /// `adb reverse tcp:8000 tcp:8000` tunnel is alive -- and that tunnel dies
  /// on every cable unplug, phone reboot and adb restart, with nothing
  /// re-creating it. The Wi-Fi address is what makes the same build keep
  /// working once it does. `10.0.2.2` is the Android emulator's alias for its
  /// host.
  static List<String> devCandidates() => [
    devApiUrl,
    'http://127.0.0.1:8000',
    if (devApiHost.isNotEmpty) 'http://$devApiHost:8000',
    if (Platform.isAndroid) 'http://10.0.2.2:8000',
  ];

  /// Resolves the base URL to talk to.
  ///
  /// Release builds always target production, so this returns immediately and
  /// never touches the network -- the local-server fallback is purely a
  /// development affordance. Probing it in release added a DNS+TCP+TLS round
  /// trip (up to the timeout on a bad network) before the first frame.
  static Future<void> init() async {
    if (kReleaseMode) return;

    final client = http.Client();
    try {
      _baseUrl = await resolveBaseUrl(
        client: client,
        candidates: devCandidates(),
      );
    } finally {
      client.close();
    }

    if (_baseUrl == productionUrl) {
      debugPrint('🌍 API: production ($_baseUrl)');
    } else {
      debugPrint('🔌 API: local dev backend ($_baseUrl)');
    }
  }

  static String get baseUrl => _baseUrl;

  static const String apiVersion = '/api/v1';

  static String get apiUrl => '$baseUrl$apiVersion';
}

/// Custom exception for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: $statusCode - $message';

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isBadRequest => statusCode == 400;
}

/// HTTP client for backend API communication
class ApiService {
  /// Ceiling on any single request. Without this a hung socket blocks the
  /// caller forever — on the splash screen that means the app never starts.
  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Uploads stream a whole file, so they get a longer ceiling.
  static const Duration _uploadTimeout = Duration(seconds: 60);

  final http.Client _client;
  final AuthService _authService;

  ApiService({http.Client? client, required AuthService authService})
    : _client = client ?? http.Client(),
      _authService = authService;

  /// Get authorization headers with JWT token
  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await _authService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Parse API response and handle errors
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Unknown error';
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] ?? body['message'] ?? message;
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : message;
    }

    throw ApiException(response.statusCode, message);
  }

  /// The one place a failed post-401 refresh is observed. Firing the shared
  /// AuthService's session-expired signal here (not in each verb) gives the
  /// app a single choke point so SessionCubit leaves Notes for Welcome
  /// instead of each feature silently swallowing a 401.
  Future<bool> _attemptRefresh() async {
    final refreshed = await _authService.refreshAccessToken();
    if (!refreshed) _authService.notifySessionExpired();
    return refreshed;
  }

  /// Perform GET request with retry on 401
  Future<dynamic> get(String endpoint, {bool requireAuth = true}) async {
    try {
      final headers = await _getHeaders(requireAuth: requireAuth);
      final response = await _client
          .get(Uri.parse('${ApiConfig.apiUrl}$endpoint'), headers: headers)
          .timeout(_requestTimeout);
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        // Token expired, try to refresh
        final refreshed = await _attemptRefresh();
        if (refreshed) {
          // Retry request with new token
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client
              .get(Uri.parse('${ApiConfig.apiUrl}$endpoint'), headers: headers)
              .timeout(_requestTimeout);
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
    } on TimeoutException {
      throw ApiException(0, 'Request timed out');
    }
  }

  /// Perform POST request with retry on 401
  Future<dynamic> post(
    String endpoint,
    dynamic body, {
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(requireAuth: requireAuth);
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.apiUrl}$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _attemptRefresh();
        if (refreshed) {
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client
              .post(
                Uri.parse('${ApiConfig.apiUrl}$endpoint'),
                headers: headers,
                body: jsonEncode(body),
              )
              .timeout(_requestTimeout);
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
    } on TimeoutException {
      throw ApiException(0, 'Request timed out');
    }
  }

  /// Perform PUT request with retry on 401
  Future<dynamic> put(
    String endpoint,
    dynamic body, {
    bool requireAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(requireAuth: requireAuth);
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.apiUrl}$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _attemptRefresh();
        if (refreshed) {
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client
              .put(
                Uri.parse('${ApiConfig.apiUrl}$endpoint'),
                headers: headers,
                body: jsonEncode(body),
              )
              .timeout(_requestTimeout);
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
    } on TimeoutException {
      throw ApiException(0, 'Request timed out');
    }
  }

  /// Perform DELETE request with retry on 401
  Future<void> delete(String endpoint, {bool requireAuth = true}) async {
    try {
      final headers = await _getHeaders(requireAuth: requireAuth);
      final response = await _client
          .delete(Uri.parse('${ApiConfig.apiUrl}$endpoint'), headers: headers)
          .timeout(_requestTimeout);
      _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _attemptRefresh();
        if (refreshed) {
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client
              .delete(
                Uri.parse('${ApiConfig.apiUrl}$endpoint'),
                headers: headers,
              )
              .timeout(_requestTimeout);
          _handleResponse(response);
          return;
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
    } on TimeoutException {
      throw ApiException(0, 'Request timed out');
    }
  }

  /// Upload file with multipart request and retry on 401
  Future<dynamic> uploadFile(
    String endpoint,
    File file, {
    String fieldName = 'file',
    Map<String, String>? fields,
    bool requireAuth = true,
  }) async {
    // Helper to create request
    Future<http.MultipartRequest> createRequest() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.apiUrl}$endpoint'),
      );
      if (requireAuth) {
        final token = await _authService.getAccessToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path),
      );
      return request;
    }

    try {
      final request = await createRequest();
      final streamedResponse = await _client
          .send(request)
          .timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _attemptRefresh();
        if (refreshed) {
          final request = await createRequest();
          final streamedResponse = await _client
              .send(request)
              .timeout(_uploadTimeout);
          final response = await http.Response.fromStream(streamedResponse);
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
    } on TimeoutException {
      throw ApiException(0, 'Request timed out');
    }
  }

  /// Lightweight reachability probe for the sync layer. Hits the ROOT /health
  /// (NOT under /api/v1), so it builds off ApiConfig.baseUrl. Returns false on
  /// any error/timeout instead of throwing.
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Close the HTTP client
  void dispose() {
    _client.close();
  }
}
