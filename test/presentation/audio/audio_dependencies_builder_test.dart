import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/backend_gemini_service.dart';
import 'package:archset_r2/data/services/whisper_service.dart';
import 'package:archset_r2/domain/services/audio_service.dart';
import 'package:archset_r2/presentation/audio/audio_dependencies_builder.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import '../../support/fake_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds an AudioService/BackendGeminiService and reuses the given '
      'WhisperService', () {
    final auth = AuthDependencies(
      repository: AuthService(database: FakeAppDatabase()),
    );
    final whisperService = WhisperService();

    final deps = AudioDependenciesBuilder.build(auth, whisperService);

    expect(deps.audioService, isA<AudioService>());
    expect(deps.geminiService, isA<BackendGeminiService>());
    expect(deps.whisperService, same(whisperService));
  });
}
