import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/notes/notes_dependencies_builder.dart';
import '../../support/fake_app_database.dart';

void main() {
  test('builds a NotesRepository wired to the core database', () {
    final database = FakeAppDatabase();
    final core = CoreDependencies(
      database: database,
      secureStorage: const FlutterSecureStorage(),
      logger: Logger(),
    );

    final deps = NotesDependenciesBuilder.build(core);

    expect(deps.repository, isA<NotesRepository>());
    expect(deps.repository.database, same(database));
  });
}
