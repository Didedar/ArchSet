import '../../data/services/whisper_service.dart';
import 'transcription_dependencies.dart';

abstract class TranscriptionDependenciesBuilder {
  static TranscriptionDependencies build() =>
      TranscriptionDependencies(whisperService: WhisperService());
}
