import '../../data/services/whisper_service.dart';

class TranscriptionDependencies {
  const TranscriptionDependencies({required this.whisperService});

  final WhisperService whisperService;
}
