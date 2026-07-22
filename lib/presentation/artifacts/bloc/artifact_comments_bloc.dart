import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/artifact.dart';
import '../../../data/repository/artifacts_repository.dart';

part 'artifact_comments_event.dart';
part 'artifact_comments_state.dart';

/// Owns the comment thread for a single artifact.
///
/// Created per detail sheet rather than globally, so it is scoped to one
/// [artifactId] for its whole life.
class ArtifactCommentsBloc
    extends Bloc<ArtifactCommentsEvent, ArtifactCommentsState> {
  ArtifactCommentsBloc({
    required ArtifactsRepository repository,
    required String artifactId,
  }) : _repository = repository,
       _artifactId = artifactId,
       super(const ArtifactCommentsInitial()) {
    on<ArtifactCommentsSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    // Sequential, not droppable: rapid submits are all real user intent and
    // none should be silently discarded.
    on<ArtifactCommentAdded>(_onAdded, transformer: sequential());
    on<ArtifactCommentEdited>(_onEdited, transformer: sequential());
    on<ArtifactCommentDeleted>(_onDeleted, transformer: sequential());
    on<_CommentsUpdated>(_onCommentsUpdated, transformer: sequential());
    on<_CommentsFailed>(_onFailed, transformer: sequential());
  }

  final ArtifactsRepository _repository;
  final String _artifactId;
  StreamSubscription<List<ArtifactComment>>? _commentsSub;

  Future<void> _onSubscriptionRequested(
    ArtifactCommentsSubscriptionRequested event,
    Emitter<ArtifactCommentsState> emit,
  ) async {
    emit(const ArtifactCommentsLoadInProgress());
    await _commentsSub?.cancel();
    _commentsSub = _repository
        .watchComments(_artifactId)
        .listen(
          (comments) => add(_CommentsUpdated(comments)),
          onError: (Object error) => add(_CommentsFailed(error.toString())),
        );
  }

  Future<void> _onAdded(
    ArtifactCommentAdded event,
    Emitter<ArtifactCommentsState> emit,
  ) async {
    // Blank submits are rejected by the UI; guard anyway so the repository's
    // ArgumentError can never surface as an unhandled bloc error.
    if (event.body.trim().isEmpty) return;
    try {
      await _repository.addComment(_artifactId, event.body);
    } catch (error) {
      emit(_currentSuccess.copyWith(actionError: error.toString()));
    }
  }

  Future<void> _onEdited(
    ArtifactCommentEdited event,
    Emitter<ArtifactCommentsState> emit,
  ) async {
    if (event.body.trim().isEmpty) return;
    try {
      await _repository.updateComment(event.commentId, event.body);
    } catch (error) {
      emit(_currentSuccess.copyWith(actionError: error.toString()));
    }
  }

  Future<void> _onDeleted(
    ArtifactCommentDeleted event,
    Emitter<ArtifactCommentsState> emit,
  ) async {
    try {
      await _repository.deleteComment(event.commentId);
    } catch (error) {
      emit(_currentSuccess.copyWith(actionError: error.toString()));
    }
  }

  void _onCommentsUpdated(
    _CommentsUpdated event,
    Emitter<ArtifactCommentsState> emit,
  ) {
    // A fresh list clears any stale one-shot error banner.
    emit(ArtifactCommentsLoadSuccess(comments: event.comments));
  }

  void _onFailed(_CommentsFailed event, Emitter<ArtifactCommentsState> emit) {
    emit(ArtifactCommentsLoadFailure(event.message));
  }

  ArtifactCommentsLoadSuccess get _currentSuccess {
    final current = state;
    return current is ArtifactCommentsLoadSuccess
        ? current
        : const ArtifactCommentsLoadSuccess();
  }

  @override
  Future<void> close() async {
    await _commentsSub?.cancel();
    return super.close();
  }
}
