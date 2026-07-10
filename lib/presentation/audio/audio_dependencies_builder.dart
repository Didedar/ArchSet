import '../../data/services/api_service.dart';
import '../../data/services/backend_gemini_service.dart';
import '../../data/services/whisper_service.dart';
import '../../domain/services/audio_service.dart';
import '../auth/auth_dependencies.dart';
import 'audio_dependencies.dart';

abstract class AudioDependenciesBuilder {
  static AudioDependencies build(
    AuthDependencies auth,
    WhisperService whisperService,
  ) {
    final apiService = ApiService(authService: auth.repository);
    return AudioDependencies(
      audioService: AudioService(),
      geminiService: BackendGeminiService(apiService: apiService),
      whisperService: whisperService,
    );
  }
}
