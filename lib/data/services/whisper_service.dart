import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

class WhisperService {
  Whisper? _whisper;
  bool _isModelLoaded = false;
  String? _modelPath;

  // Use the multilingual base model (NOT base.en!)
  static const String _modelUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin';
  static const String _modelFileName = 'ggml-base.bin';

  Future<bool> isModelDownloaded() async {
    final path = await _getModelPath();
    final file = File(path);
    return file.exists();
  }

  Future<String> _getModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_modelFileName';
  }

  Future<void> downloadModel({
    required Function(double progress) onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_modelUrl));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 142000000;
      final path = await _getModelPath();
      final file = File(path);

      final sink = file.openWrite();
      int received = 0;

      await response.stream
          .listen(
            (chunk) {
              received += chunk.length;
              sink.add(chunk);
              onProgress(received / contentLength);
            },
            onDone: () async {
              await sink.close();
              client.close();
            },
            onError: (e) {
              sink.close();
              client.close();
              throw e;
            },
            cancelOnError: true,
          )
          .asFuture();

      _modelPath = path;
    } catch (e) {
      debugPrint('Error downloading model: $e');
      rethrow;
    }
  }

  Future<void> init() async {
    if (_isModelLoaded) return;
    try {
      final path = await _getModelPath();
      if (await File(path).exists()) {
        _modelPath = path;
        // Important: use WhisperModel.base (it is multilingual)
        _whisper = const Whisper(model: WhisperModel.base);
        _isModelLoaded = true;
      }
    } catch (e) {
      debugPrint('Error initializing Whisper: $e');
    }
  }

  /// Transcribes audio in the source language (without translation)
  Future<String?> transcribe(String audioPath, {String language = 'ru'}) async {
    if (!_isModelLoaded) await init();
    if (!_isModelLoaded || _whisper == null) return null;

    try {
      // KEY POINTS:
      // 1. language: 'auto' forces Whisper to detect language and transcribe in it.
      // 2. If known (e.g. Russian), pass 'ru'.
      final req = TranscribeRequest(
        audio: audioPath,
        language: 'ru', // Forced to 'ru' as requested
        isTranslate: false, // GUARANTEES no translation to English
        isNoTimestamps: true, // Clean text without timestamps
      );

      final res = await _whisper!.transcribe(
        modelPath: _modelPath!,
        transcribeRequest: req,
      );

      return res.text.trim();
    } catch (e) {
      debugPrint('Whisper transcription error: $e');
      return null;
    }
  }

  /// Delete the model
  Future<void> deleteModel() async {
    final path = await _getModelPath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      _isModelLoaded = false;
      _modelPath = null;
      _whisper = null;
    }
  }
}
