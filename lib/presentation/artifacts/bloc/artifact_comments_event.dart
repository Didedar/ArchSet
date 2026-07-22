part of 'artifact_comments_bloc.dart';

sealed class ArtifactCommentsEvent {
  const ArtifactCommentsEvent();
}

final class ArtifactCommentsSubscriptionRequested
    extends ArtifactCommentsEvent {
  const ArtifactCommentsSubscriptionRequested();
}

final class ArtifactCommentAdded extends ArtifactCommentsEvent {
  const ArtifactCommentAdded(this.body);

  final String body;
}

final class ArtifactCommentEdited extends ArtifactCommentsEvent {
  const ArtifactCommentEdited(this.commentId, this.body);

  final String commentId;
  final String body;
}

final class ArtifactCommentDeleted extends ArtifactCommentsEvent {
  const ArtifactCommentDeleted(this.commentId);

  final String commentId;
}

final class _CommentsUpdated extends ArtifactCommentsEvent {
  const _CommentsUpdated(this.comments);

  final List<ArtifactComment> comments;
}

final class _CommentsFailed extends ArtifactCommentsEvent {
  const _CommentsFailed(this.message);

  final String message;
}
