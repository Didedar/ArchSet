import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/whisper_service.dart';

enum TranscriptionEngine { gemini, whisper }

class TranscriptionState {
  final TranscriptionEngine engine;
  final bool isModelDownloaded;
  final bool isDownloading;
  final double downloadProgress;

  const TranscriptionState({
    this.engine = TranscriptionEngine.gemini,
    this.isModelDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  TranscriptionState copyWith({
    TranscriptionEngine? engine,
    bool? isModelDownloaded,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return TranscriptionState(
      engine: engine ?? this.engine,
      isModelDownloaded: isModelDownloaded ?? this.isModelDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

class TranscriptionNotifier extends StateNotifier<TranscriptionState> {
  final WhisperService _whisperService;

  TranscriptionNotifier(this._whisperService)
    : super(const TranscriptionState()) {
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final downloaded = await _whisperService.isModelDownloaded();
    state = state.copyWith(isModelDownloaded: downloaded);
  }

  void setEngine(TranscriptionEngine engine) {
    state = state.copyWith(engine: engine);
  }

  Future<void> downloadModel() async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true, downloadProgress: 0.0);
    try {
      await _whisperService.downloadModel(
        onProgress: (progress) {
          state = state.copyWith(downloadProgress: progress);
        },
      );
      state = state.copyWith(
        isDownloading: false,
        isModelDownloaded: true,
        downloadProgress: 1.0,
      );
      // Initialize after download
      await _whisperService.init();
    } catch (e) {
      state = state.copyWith(isDownloading: false, downloadProgress: 0.0);
      rethrow;
    }
  }

  Future<void> initWhisper() async {
    await _whisperService.init();
  }
}

final whisperServiceProvider = Provider<WhisperService>((ref) {
  return WhisperService();
});

final transcriptionProvider =
    StateNotifierProvider<TranscriptionNotifier, TranscriptionState>((ref) {
      final whisperService = ref.watch(whisperServiceProvider);
      return TranscriptionNotifier(whisperService);
    });
