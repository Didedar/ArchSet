import 'dart:async';

import 'package:archset_r2/data/models/artifact.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
import 'package:archset_r2/presentation/artifacts/bloc/artifact_comments_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockArtifactsRepository extends Mock implements ArtifactsRepository {}

ArtifactComment _comment(String id, String body) => ArtifactComment(
  id: id,
  artifactId: 'artifact-1',
  body: body,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  const artifactId = 'artifact-1';

  late _MockArtifactsRepository repository;
  late StreamController<List<ArtifactComment>> commentsController;

  setUp(() {
    repository = _MockArtifactsRepository();
    commentsController = StreamController<List<ArtifactComment>>.broadcast();
    when(
      () => repository.watchComments(artifactId),
    ).thenAnswer((_) => commentsController.stream);
    when(
      () => repository.addComment(any(), any()),
    ).thenAnswer((_) async => 'new-id');
    when(() => repository.updateComment(any(), any())).thenAnswer((_) async {});
    when(() => repository.deleteComment(any())).thenAnswer((_) async {});
  });

  tearDown(() => commentsController.close());

  ArtifactCommentsBloc buildBloc() =>
      ArtifactCommentsBloc(repository: repository, artifactId: artifactId);

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'emits the comment thread from the repository stream',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const ArtifactCommentsSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      commentsController.add([_comment('1', 'first')]);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const ArtifactCommentsLoadInProgress(),
      isA<ArtifactCommentsLoadSuccess>().having(
        (s) => s.comments.single.body,
        'body',
        'first',
      ),
    ],
  );

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'forwards an added comment to the repository scoped to this artifact',
    build: buildBloc,
    act: (bloc) => bloc.add(const ArtifactCommentAdded('a note')),
    verify: (_) {
      verify(() => repository.addComment(artifactId, 'a note')).called(1);
    },
  );

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'ignores a whitespace-only comment without touching the repository',
    build: buildBloc,
    act: (bloc) => bloc.add(const ArtifactCommentAdded('   ')),
    expect: () => const <ArtifactCommentsState>[],
    verify: (_) {
      verifyNever(() => repository.addComment(any(), any()));
    },
  );

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'processes rapid submissions instead of dropping them',
    build: buildBloc,
    act: (bloc) {
      bloc
        ..add(const ArtifactCommentAdded('one'))
        ..add(const ArtifactCommentAdded('two'))
        ..add(const ArtifactCommentAdded('three'));
    },
    wait: const Duration(milliseconds: 50),
    verify: (_) {
      verify(() => repository.addComment(artifactId, any())).called(3);
    },
  );

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'reports an add failure without losing the loaded thread',
    build: () {
      when(
        () => repository.addComment(any(), any()),
      ).thenThrow(Exception('disk full'));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const ArtifactCommentsSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      commentsController.add([_comment('1', 'existing')]);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ArtifactCommentAdded('will fail'));
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) {
      final state = bloc.state as ArtifactCommentsLoadSuccess;
      expect(state.actionError, isNotNull);
      expect(state.comments.single.body, 'existing');
    },
  );

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'a fresh stream emission clears a stale action error',
    build: () {
      when(
        () => repository.addComment(any(), any()),
      ).thenThrow(Exception('transient'));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const ArtifactCommentsSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ArtifactCommentAdded('will fail'));
      await Future<void>.delayed(Duration.zero);
      commentsController.add([_comment('1', 'recovered')]);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) {
      expect((bloc.state as ArtifactCommentsLoadSuccess).actionError, isNull);
    },
  );

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'forwards edit and delete to the repository',
    build: buildBloc,
    act: (bloc) {
      bloc
        ..add(const ArtifactCommentEdited('c1', 'revised'))
        ..add(const ArtifactCommentDeleted('c2'));
    },
    wait: const Duration(milliseconds: 50),
    verify: (_) {
      verify(() => repository.updateComment('c1', 'revised')).called(1);
      verify(() => repository.deleteComment('c2')).called(1);
    },
  );

  blocTest<ArtifactCommentsBloc, ArtifactCommentsState>(
    'surfaces a stream error as a failure state',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const ArtifactCommentsSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      commentsController.addError(Exception('db gone'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const ArtifactCommentsLoadInProgress(),
      isA<ArtifactCommentsLoadFailure>(),
    ],
  );

  test('cancels its subscription on close', () async {
    final bloc = buildBloc();
    bloc.add(const ArtifactCommentsSubscriptionRequested());
    await Future<void>.delayed(Duration.zero);

    expect(commentsController.hasListener, isTrue);

    await bloc.close();

    expect(commentsController.hasListener, isFalse);
  });
}
