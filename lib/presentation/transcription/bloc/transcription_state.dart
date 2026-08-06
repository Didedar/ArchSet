part of 'transcription_bloc.dart';

enum TranscriptionEngine { gemini, whisper }

final class TranscriptionState extends Equatable {
  const TranscriptionState({
    this.engine = TranscriptionEngine.gemini,
    this.isModelDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  final TranscriptionEngine engine;
  final bool isModelDownloaded;
  final bool isDownloading;
  final double downloadProgress;

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

  @override
  List<Object?> get props => [
    engine,
    isModelDownloaded,
    isDownloading,
    downloadProgress,
  ];
}
