import '../presentation/audio/audio_dependencies.dart';
import '../presentation/auth/auth_dependencies.dart';
import '../presentation/core_deps/core_dependencies.dart';
import '../presentation/editor/editor_dependencies.dart';
import '../presentation/locale/locale_dependencies.dart';
import '../presentation/notes/notes_dependencies.dart';
import '../presentation/sync/sync_dependencies.dart';
import '../presentation/theme/theme_dependencies.dart';
import '../presentation/transcription/transcription_dependencies.dart';

/// Aggregate of every feature's dependency container. Grows one field per
/// feature as each is migrated off Riverpod.
class Dependencies {
  const Dependencies({
    required this.core,
    required this.theme,
    required this.locale,
    required this.auth,
    required this.sync,
    required this.notes,
    required this.transcription,
    required this.audio,
    required this.editor,
  });

  final CoreDependencies core;
  final ThemeDependencies theme;
  final LocaleDependencies locale;
  final AuthDependencies auth;
  final SyncDependencies sync;
  final NotesDependencies notes;
  final TranscriptionDependencies transcription;
  final AudioDependencies audio;
  final EditorDependencies editor;
}
