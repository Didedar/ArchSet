import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repository/notes_repository.dart';
import '../../domain/services/audio_service.dart';

/// Database provider.
///
/// Notes/Folders reads now go through [NotesBloc]/[FoldersBloc] (see
/// `presentation/notes/`), but this stays as a Riverpod bridge for the
/// not-yet-migrated call sites that need a static reference
/// (auth_provider.dart, diary_edit_page.dart).
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Notes repository provider.
///
/// Kept for diary_edit_page.dart (Phase 5, not yet migrated); Notes/Folders
/// pages now construct [NotesRepository] via the composition root instead.
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return NotesRepository(database);
});

// ==================== AUDIO SERVICE ====================

/// Audio service provider
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
