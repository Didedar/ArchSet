/// API client for communicating with the ArchSet backend.
///
/// Handles HTTP requests, authentication headers, and error handling.
library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'auth_service.dart';

/// API configuration
class ApiConfig {
  static String _baseUrl = 'http://127.0.0.1:8000'; // Default to localhost

  /// Initialize API configuration
  /// Must be called before runApp
  static Future<void> init() async {
    if (Platform.isAndroid) {
      _baseUrl = 'http://10.240.102.24:8000';
    } else if (Platform.isIOS) {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;

      if (iosInfo.isPhysicalDevice) {
        // Physical iOS device - use mDNS hostname
        _baseUrl = 'http://MacBook-Air-Gulnazira.local:8000';
      } else {
        // iOS Simulator - use localhost
        _baseUrl = 'http://127.0.0.1:8000';
      }
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

  /// Perform GET request with retry on 401
  Future<dynamic> get(String endpoint, {bool requireAuth = true}) async {
    try {
      final headers = await _getHeaders(requireAuth: requireAuth);
      final response = await _client.get(
        Uri.parse('${ApiConfig.apiUrl}$endpoint'),
        headers: headers,
      );
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        // Token expired, try to refresh
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          // Retry request with new token
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client.get(
            Uri.parse('${ApiConfig.apiUrl}$endpoint'),
            headers: headers,
          );
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
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
      final response = await _client.post(
        Uri.parse('${ApiConfig.apiUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client.post(
            Uri.parse('${ApiConfig.apiUrl}$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          );
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
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
      final response = await _client.put(
        Uri.parse('${ApiConfig.apiUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client.put(
            Uri.parse('${ApiConfig.apiUrl}$endpoint'),
            headers: headers,
            body: jsonEncode(body),
          );
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
    }
  }

  /// Perform DELETE request with retry on 401
  Future<void> delete(String endpoint, {bool requireAuth = true}) async {
    try {
      final headers = await _getHeaders(requireAuth: requireAuth);
      final response = await _client.delete(
        Uri.parse('${ApiConfig.apiUrl}$endpoint'),
        headers: headers,
      );
      _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          final headers = await _getHeaders(requireAuth: requireAuth);
          final response = await _client.delete(
            Uri.parse('${ApiConfig.apiUrl}$endpoint'),
            headers: headers,
          );
          _handleResponse(response);
          return;
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
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
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.isUnauthorized && requireAuth) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          final request = await createRequest();
          final streamedResponse = await _client.send(request);
          final response = await http.Response.fromStream(streamedResponse);
          return _handleResponse(response);
        }
      }
      rethrow;
    } on SocketException {
      throw ApiException(0, 'No internet connection');
    }
  }

  /// Close the HTTP client
  void dispose() {
    _client.close();
  }
}
