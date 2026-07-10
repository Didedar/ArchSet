part of 'editor_bloc.dart';

sealed class EditorEvent {
  const EditorEvent();
}

/// Persists the note being edited. [plainText] (the rendered document
/// text, distinct from [contentJson]'s serialized Quill Delta) is used
/// only to decide whether the note is empty and should be skipped.
final class EditorSaveRequested extends EditorEvent {
  const EditorSaveRequested({
    required this.noteId,
    required this.title,
    required this.contentJson,
    required this.plainText,
    required this.folderId,
    required this.audioPath,
  });

  final String noteId;
  final String title;
  final String contentJson;
  final String plainText;
  final String? folderId;
  final String? audioPath;
}

/// Attempts an online hard delete first; falls back to a local soft
/// delete (picked up later by sync) if the backend is unreachable.
final class EditorDeleteRequested extends EditorEvent {
  const EditorDeleteRequested(this.noteId);

  final String noteId;
}

final class EditorAiRewriteRequested extends EditorEvent {
  const EditorAiRewriteRequested(this.plainText);

  final String plainText;
}

final class EditorImageScanRequested extends EditorEvent {
  const EditorImageScanRequested(this.imagePath);

  final String imagePath;
}
