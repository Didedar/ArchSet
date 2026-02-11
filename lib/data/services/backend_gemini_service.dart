/// Backend-powered Gemini service for audio transcription and AI rewriting.
///
/// This service uses the Python backend API instead of calling Gemini directly,
/// which keeps the API key secure on the server.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Gemini service that uses backend API
class BackendGeminiService {
  final ApiService _apiService;

  BackendGeminiService({required ApiService apiService})
    : _apiService = apiService;

  /// Transcribe audio file using backend Gemini API
  ///
  /// [path] - Path to the audio file to transcribe
  /// Returns transcribed text or null if error
  Future<String?> transcribeAudio(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[BackendGeminiService] Audio file not found: $path');
        return null;
      }

      debugPrint(
        '[BackendGeminiService] Uploading audio for transcription: $path',
      );

      final response = await _apiService.uploadFile(
        '/gemini/transcribe',
        file,
        fieldName: 'file',
      );

      if (response['success'] == true) {
        return response['text'] as String?;
      } else {
        debugPrint(
          '[BackendGeminiService] Transcription failed: ${response['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[BackendGeminiService] Transcription error: $e');
      return null;
    }
  }

  /// Rewrite text according to archaeological field documentation standards
  ///
  /// [text] - Original text to rewrite
  /// Returns rewritten text or null if error
  Future<String?> rewriteForArchaeology(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      debugPrint('[BackendGeminiService] Rewriting text for archaeology');

      final response = await _apiService.post('/gemini/rewrite', {
        'text': text,
      });

      if (response['success'] == true) {
        return response['rewritten_text'] as String?;
      } else {
        debugPrint(
          '[BackendGeminiService] Rewrite failed: ${response['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[BackendGeminiService] Rewrite error: $e');
      return null;
    }
  }

  /// Chat with the diary context
  ///
  /// [query] - User question
  /// [history] - Chat history (optional)
  /// Returns AI response or null if error
  Future<String?> chatWithDiary(
    String query, {
    List<Map<String, dynamic>> history = const [],
  }) async {
    if (query.trim().isEmpty) return null;

    try {
      debugPrint('[BackendGeminiService] Chatting with diary: $query');

      final response = await _apiService.post('/ai/chat', {
        'query': query,
        'history': history,
      });

      if (response['success'] == true) {
        return response['response'] as String?;
      } else {
        debugPrint('[BackendGeminiService] Chat failed: ${response['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('[BackendGeminiService] Chat error: $e');
      return null;
    }
  }

  /// Analyze an image to extract archaeological context
  ///
  /// [path] - Path to the image file
  /// [latitude] - Optional latitude
  /// [longitude] - Optional longitude
  /// Returns JSON string with analysis or null if error
  Future<String?> analyzeImage(
    String path, {
    double? latitude,
    double? longitude,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[BackendGeminiService] Image file not found: $path');
        return null;
      }

      debugPrint('[BackendGeminiService] Uploading image for analysis: $path');

      final fields = <String, String>{};
      if (latitude != null) fields['latitude'] = latitude.toString();
      if (longitude != null) fields['longitude'] = longitude.toString();

      final response = await _apiService.uploadFile(
        '/gemini/analyze-image',
        file,
        fieldName: 'file',
        fields: fields,
      );

      if (response['success'] == true) {
        return response['analysis'] as String?;
      } else {
        debugPrint(
          '[BackendGeminiService] Image analysis failed: ${response['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[BackendGeminiService] Image analysis error: $e');
      return null;
    }
  }

  /// Extract text from an image (OCR)
  ///
  /// [path] - Path to the image file
  /// Returns extracted text or null if error
  Future<String?> extractTextFromImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[BackendGeminiService] Image OCR: File not found: $path');
        return null;
      }

      debugPrint('[BackendGeminiService] Uploading image for OCR: $path');

      final response = await _apiService.uploadFile(
        '/gemini/ocr',
        file,
        fieldName: 'file',
      );

      if (response['success'] == true) {
        return response['text'] as String?;
      } else {
        debugPrint('[BackendGeminiService] OCR failed: ${response['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('[BackendGeminiService] OCR error: $e');
      return null;
    }
  }
}
