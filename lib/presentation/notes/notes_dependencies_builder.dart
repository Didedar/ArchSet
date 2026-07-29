import '../../data/repository/notes_repository.dart';
import '../core_deps/core_dependencies.dart';
import 'notes_dependencies.dart';

abstract class NotesDependenciesBuilder {
  static NotesDependencies build(CoreDependencies core) {
    return NotesDependencies(
      repository: NotesRepository(
        core.database,
        ownerHolder: core.currentOwner,
      ),
    );
  }
}
