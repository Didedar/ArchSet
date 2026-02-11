import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Editor content tabs
enum EditorTab { content, transcription, aiRewrite }

/// Current active tab in editor
final currentEditorTabProvider = StateProvider<EditorTab>((ref) {
  return EditorTab.content;
});

/// Recording state
final isRecordingProvider = StateProvider<bool>((ref) => false);

/// Audio file path for current note
final currentAudioPathProvider = StateProvider<String?>((ref) => null);

/// Dirty flag - true if note has unsaved changes
final isDirtyProvider = StateProvider<bool>((ref) => false);

/// Autosave in progress
final isSavingProvider = StateProvider<bool>((ref) => false);
