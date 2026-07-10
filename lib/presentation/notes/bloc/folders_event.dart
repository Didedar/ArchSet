part of 'folders_bloc.dart';

sealed class FoldersEvent {
  const FoldersEvent();
}

final class FoldersSubscriptionRequested extends FoldersEvent {
  const FoldersSubscriptionRequested();
}

final class FoldersCreateRequested extends FoldersEvent {
  const FoldersCreateRequested(this.folder);

  final Folder folder;
}

final class FoldersDeleteRequested extends FoldersEvent {
  const FoldersDeleteRequested(this.folderId);

  final String folderId;
}

final class _FoldersUpdated extends FoldersEvent {
  const _FoldersUpdated(this.folders);

  final List<Folder> folders;
}

final class _FolderCountsUpdated extends FoldersEvent {
  const _FolderCountsUpdated(this.counts);

  final Map<String, int> counts;
}

final class _AllNotesCountUpdated extends FoldersEvent {
  const _AllNotesCountUpdated(this.count);

  final int count;
}
