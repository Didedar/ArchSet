part of 'notes_bloc.dart';

sealed class NotesEvent {
  const NotesEvent();
}

/// Subscribes to all notes ([folderId] null) or notes in one folder.
/// Re-dispatching with a different [folderId] retargets the subscription.
final class NotesSubscriptionRequested extends NotesEvent {
  const NotesSubscriptionRequested({this.folderId});

  final String? folderId;
}

final class NotesDeleteRequested extends NotesEvent {
  const NotesDeleteRequested(this.noteId);

  final String noteId;
}

final class NotesMoveToFolderRequested extends NotesEvent {
  const NotesMoveToFolderRequested(this.noteId, this.folderId);

  final String noteId;
  final String? folderId;
}
