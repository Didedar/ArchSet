import '../../data/repository/notes_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/backend_gemini_service.dart';

class EditorDependencies {
  const EditorDependencies({
    required this.notesRepository,
    required this.geminiService,
    required this.apiService,
  });

  final NotesRepository notesRepository;
  final BackendGeminiService geminiService;
  final ApiService apiService;
}
