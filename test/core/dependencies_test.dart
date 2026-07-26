import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/repository/secure_storage_locale_repository.dart';
import 'package:archset_r2/data/repository/secure_storage_theme_repository.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/domain/services/audio_service.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
import 'package:archset_r2/presentation/artifacts/artifacts_dependencies.dart';
import 'package:archset_r2/presentation/audio/audio_dependencies.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/editor/editor_dependencies.dart';
import 'package:archset_r2/presentation/locale/locale_dependencies.dart';
import 'package:archset_r2/presentation/notes/notes_dependencies.dart';
import 'package:archset_r2/presentation/sync/sync_dependencies.dart';
import 'package:archset_r2/presentation/theme/theme_dependencies.dart';
import 'package:archset_r2/presentation/transcription/transcription_dependencies.dart';
import 'package:archset_r2/data/services/backend_gemini_service.dart';
import 'package:archset_r2/data/services/whisper_service.dart';
import '../support/fake_app_database.dart';
import '../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  test('exposes every feature dependency container it was built with', () {
    final storage = const FlutterSecureStorage();
    final database = FakeAppDatabase();
    final core = CoreDependencies(
      database: database,
      secureStorage: storage,
      logger: Logger(),
    );
    final theme = ThemeDependencies(
      repository: SecureStorageThemeRepository(storage: storage),
    );
    final locale = LocaleDependencies(
      repository: SecureStorageLocaleRepository(storage: storage),
    );
    final authService = AuthService(database: database);
    final auth = AuthDependencies(repository: authService);
    final sync = SyncDependencies(
      service: SyncService(
        apiService: ApiService(authService: authService),
        database: database,
      ),
    );
    final notes = NotesDependencies(repository: NotesRepository(database));
    final whisperService = WhisperService();
    final transcription = TranscriptionDependencies(
      whisperService: whisperService,
    );
    final apiService = ApiService(authService: authService);
    final audio = AudioDependencies(
      audioService: AudioService(),
      geminiService: BackendGeminiService(apiService: apiService),
      whisperService: whisperService,
    );
    final editor = EditorDependencies(
      notesRepository: NotesRepository(database),
      geminiService: BackendGeminiService(apiService: apiService),
      apiService: apiService,
    );

    final artifacts = ArtifactsDependencies(
      repository: ArtifactsRepository(database),
    );

    final dependencies = Dependencies(
      core: core,
      theme: theme,
      locale: locale,
      auth: auth,
      sync: sync,
      notes: notes,
      transcription: transcription,
      audio: audio,
      editor: editor,
      artifacts: artifacts,
    );

    expect(dependencies.core, same(core));
    expect(dependencies.theme, same(theme));
    expect(dependencies.locale, same(locale));
    expect(dependencies.auth, same(auth));
    expect(dependencies.sync, same(sync));
    expect(dependencies.notes, same(notes));
    expect(dependencies.transcription, same(transcription));
    expect(dependencies.audio, same(audio));
    expect(dependencies.editor, same(editor));
    expect(dependencies.artifacts, same(artifacts));
  });
}
