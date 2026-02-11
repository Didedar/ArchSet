import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repository/notes_repository.dart';
import '../../domain/services/audio_service.dart';

/// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Notes repository provider
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return NotesRepository(database);
});

// ==================== NOTES PROVIDERS ====================

/// Stream of all notes
final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchAllNotes();
});

/// Stream of notes in a specific folder
final notesInFolderProvider = StreamProvider.family<List<Note>, String?>((
  ref,
  folderId,
) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchNotesInFolder(folderId);
});

/// Current note being edited (null for new note)
final currentNoteProvider = StateProvider<Note?>((ref) => null);

// ==================== FOLDERS PROVIDERS ====================

/// Stream of all folders
final foldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchAllFolders();
});

/// Stream of note counts per folder
final folderNoteCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchFolderNoteCounts();
});

/// Count of notes without a folder ("All Notes")
final allNotesCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchAllNotesCount();
});

/// Currently selected folder (null = viewing all notes)
final selectedFolderProvider = StateProvider<Folder?>((ref) => null);

/// Folder being created/edited
final editingFolderProvider = StateProvider<Folder?>((ref) => null);

// ==================== AUDIO SERVICE ====================

/// Audio service provider
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// ==================== LOADING STATES ====================

/// Notes loading state
enum NotesLoadingState { loading, loaded, error }

final notesLoadingStateProvider = StateProvider<NotesLoadingState>((ref) {
  return NotesLoadingState.loading;
});
