import '../../data/repository/notes_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/backend_gemini_service.dart';
import '../auth/auth_dependencies.dart';
import '../core_deps/core_dependencies.dart';
import 'editor_dependencies.dart';

abstract class EditorDependenciesBuilder {
  static EditorDependencies build(
    CoreDependencies core,
    AuthDependencies auth,
  ) {
    final apiService = ApiService(authService: auth.repository);
    return EditorDependencies(
      notesRepository: NotesRepository(core.database),
      geminiService: BackendGeminiService(apiService: apiService),
      apiService: apiService,
    );
  }
}
