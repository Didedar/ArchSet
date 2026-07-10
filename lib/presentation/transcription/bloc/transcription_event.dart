part of 'transcription_bloc.dart';

sealed class TranscriptionEvent {
  const TranscriptionEvent();
}

/// Checks whether the Whisper model is already downloaded on disk.
final class TranscriptionModelStatusChecked extends TranscriptionEvent {
  const TranscriptionModelStatusChecked();
}

final class TranscriptionEngineChanged extends TranscriptionEvent {
  const TranscriptionEngineChanged(this.engine);

  final TranscriptionEngine engine;
}

final class TranscriptionModelDownloadRequested extends TranscriptionEvent {
  const TranscriptionModelDownloadRequested();
}
