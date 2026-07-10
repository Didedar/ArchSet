part of 'folders_bloc.dart';

sealed class FoldersState extends Equatable {
  const FoldersState();

  @override
  List<Object?> get props => [];
}

final class FoldersInitial extends FoldersState {
  const FoldersInitial();
}

final class FoldersLoadInProgress extends FoldersState {
  const FoldersLoadInProgress();
}

final class FoldersLoadSuccess extends FoldersState {
  const FoldersLoadSuccess({
    this.folders = const [],
    this.folderCounts = const {},
    this.allNotesCount = 0,
  });

  final List<Folder> folders;
  final Map<String, int> folderCounts;
  final int allNotesCount;

  FoldersLoadSuccess copyWith({
    List<Folder>? folders,
    Map<String, int>? folderCounts,
    int? allNotesCount,
  }) {
    return FoldersLoadSuccess(
      folders: folders ?? this.folders,
      folderCounts: folderCounts ?? this.folderCounts,
      allNotesCount: allNotesCount ?? this.allNotesCount,
    );
  }

  @override
  List<Object?> get props => [folders, folderCounts, allNotesCount];
}

final class FoldersLoadFailure extends FoldersState {
  const FoldersLoadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
