import '../../data/services/backend_gemini_service.dart';
import '../../data/services/whisper_service.dart';
import '../../domain/services/audio_service.dart';

class AudioDependencies {
  const AudioDependencies({
    required this.audioService,
    required this.geminiService,
    required this.whisperService,
  });

  final AudioService audioService;
  final BackendGeminiService geminiService;
  final WhisperService whisperService;
}
