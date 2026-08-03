import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/backend_gemini_service.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/editor/editor_dependencies_builder.dart';
import '../../support/fake_app_database.dart';

void main() {
  test(
    'builds a NotesRepository and BackendGeminiService wired to core/auth',
    () {
      final database = FakeAppDatabase();
      final core = CoreDependencies(
        database: database,
        secureStorage: const FlutterSecureStorage(),
        logger: Logger(),
      );
      final auth = AuthDependencies(repository: AuthService());

      final deps = EditorDependenciesBuilder.build(core, auth);

      expect(deps.notesRepository, isA<NotesRepository>());
      expect(deps.notesRepository.database, same(database));
      expect(deps.geminiService, isA<BackendGeminiService>());
    },
  );
}
