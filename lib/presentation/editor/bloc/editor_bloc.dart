import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repository/notes_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/backend_gemini_service.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({
    required NotesRepository notesRepository,
    required BackendGeminiService geminiService,
    required ApiService apiService,
  }) : _notesRepository = notesRepository,
       _geminiService = geminiService,
       _apiService = apiService,
       super(const EditorIdle()) {
    on<EditorSaveRequested>(_onSaveRequested, transformer: droppable());
    on<EditorDeleteRequested>(_onDeleteRequested, transformer: droppable());
    on<EditorAiRewriteRequested>(
      _onAiRewriteRequested,
      transformer: droppable(),
    );
    on<EditorImageScanRequested>(
      _onImageScanRequested,
      transformer: droppable(),
    );
  }

  final NotesRepository _notesRepository;
  final BackendGeminiService _geminiService;
  final ApiService _apiService;

  Future<void> _onSaveRequested(
    EditorSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    emit(const EditorSaveInProgress());

    if (event.title.isEmpty && event.plainText.isEmpty) {
      emit(const EditorSaveSuccess());
      return;
    }

    final note = Note(
      id: event.noteId,
      title: event.title,
      content: event.contentJson,
      date: DateTime.now(),
      folderId: event.folderId,
      audioPath: event.audioPath,
      updatedAt: DateTime.now(),
      isDeleted: false,
      pendingSync: false,
    );
    await _notesRepository.insertNote(note);
    emit(const EditorSaveSuccess());
  }

  Future<void> _onDeleteRequested(
    EditorDeleteRequested event,
    Emitter<EditorState> emit,
  ) async {
    emit(const EditorDeleteInProgress());

    var deletedOnline = false;
    try {
      await _apiService.delete('/notes/${event.noteId}?hard_delete=true');
      deletedOnline = true;
    } catch (_) {
      deletedOnline = false;
    }

    if (deletedOnline) {
      await _notesRepository.hardDeleteNote(event.noteId);
    } else {
      await _notesRepository.deleteNote(event.noteId);
    }
    emit(const EditorDeleteSuccess());
  }

  Future<void> _onAiRewriteRequested(
    EditorAiRewriteRequested event,
    Emitter<EditorState> emit,
  ) async {
    emit(const EditorAiRewriteInProgress());
    try {
      final rewrittenText = await _geminiService.rewriteForArchaeology(
        event.plainText,
      );
      if (rewrittenText == null || rewrittenText.isEmpty) {
        emit(const EditorAiRewriteFailure());
      } else {
        emit(EditorAiRewriteSuccess(rewrittenText));
      }
    } catch (e) {
      emit(EditorAiRewriteFailure(exceptionMessage: e.toString()));
    }
  }

  Future<void> _onImageScanRequested(
    EditorImageScanRequested event,
    Emitter<EditorState> emit,
  ) async {
    emit(const EditorScanInProgress());
    try {
      final text = await _geminiService.extractTextFromImage(event.imagePath);
      if (text != null && text.isNotEmpty) {
        emit(EditorScanSuccess(text));
      } else {
        emit(const EditorScanFailure(message: 'Failed to extract text'));
      }
    } catch (_) {
      // Matches the original: an exception here is only debugPrint'd, not
      // surfaced to the user.
      emit(const EditorScanFailure());
    }
  }
}
