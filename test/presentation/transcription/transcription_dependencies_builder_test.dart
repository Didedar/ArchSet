import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/data/services/whisper_service.dart';
import 'package:archset_r2/presentation/transcription/transcription_dependencies_builder.dart';

void main() {
  test('builds a WhisperService', () {
    final deps = TranscriptionDependenciesBuilder.build();

    expect(deps.whisperService, isA<WhisperService>());
  });
}
