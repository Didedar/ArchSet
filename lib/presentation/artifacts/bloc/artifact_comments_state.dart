part of 'artifact_comments_bloc.dart';

sealed class ArtifactCommentsState extends Equatable {
  const ArtifactCommentsState();

  @override
  List<Object?> get props => [];
}

final class ArtifactCommentsInitial extends ArtifactCommentsState {
  const ArtifactCommentsInitial();
}

final class ArtifactCommentsLoadInProgress extends ArtifactCommentsState {
  const ArtifactCommentsLoadInProgress();
}

final class ArtifactCommentsLoadSuccess extends ArtifactCommentsState {
  const ArtifactCommentsLoadSuccess({
    this.comments = const [],
    this.actionError,
  });

  /// Comments oldest first, so the sheet reads as a thread.
  final List<ArtifactComment> comments;

  /// Set when an add/edit/delete failed while the list itself is still fine.
  /// Cleared on the next stream emission.
  final String? actionError;

  bool get isEmpty => comments.isEmpty;

  ArtifactCommentsLoadSuccess copyWith({
    List<ArtifactComment>? comments,
    String? actionError,
  }) {
    return ArtifactCommentsLoadSuccess(
      comments: comments ?? this.comments,
      actionError: actionError ?? this.actionError,
    );
  }

  @override
  List<Object?> get props => [comments, actionError];
}

final class ArtifactCommentsLoadFailure extends ArtifactCommentsState {
  const ArtifactCommentsLoadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
