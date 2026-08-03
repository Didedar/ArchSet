import 'dart:async';

import 'package:archset_r2/data/models/artifact.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
import 'package:archset_r2/presentation/artifacts/bloc/artifacts_map_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockArtifactsRepository extends Mock implements ArtifactsRepository {}

Artifact _artifact(String id) => Artifact(
  id: id,
  imagePath: '/photos/$id.jpg',
  latitude: 10,
  longitude: 20,
  capturedAt: DateTime(2026, 1, 1),
);

void main() {
  late _MockArtifactsRepository repository;
  late StreamController<List<Artifact>> artifactsController;
  late StreamController<int> unlocatedController;

  setUp(() {
    repository = _MockArtifactsRepository();
    artifactsController = StreamController<List<Artifact>>.broadcast();
    unlocatedController = StreamController<int>.broadcast();
    when(
      () => repository.watchLocatedArtifacts(),
    ).thenAnswer((_) => artifactsController.stream);
    when(
      () => repository.watchUnlocatedCount(),
    ).thenAnswer((_) => unlocatedController.stream);
  });

  tearDown(() {
    artifactsController.close();
    unlocatedController.close();
  });

  blocTest<ArtifactsMapBloc, ArtifactsMapState>(
    'combines the artifact and unlocated-count streams into one state',
    build: () => ArtifactsMapBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const ArtifactsMapSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      artifactsController.add([_artifact('1')]);
      await Future<void>.delayed(Duration.zero);
      unlocatedController.add(3);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const ArtifactsMapLoadInProgress(),
      isA<ArtifactsMapLoadSuccess>()
          .having((s) => s.artifacts.length, 'artifacts', 1)
          .having((s) => s.unlocatedCount, 'unlocatedCount', 0),
      isA<ArtifactsMapLoadSuccess>()
          .having((s) => s.artifacts.length, 'artifacts', 1)
          .having((s) => s.unlocatedCount, 'unlocatedCount', 3),
    ],
  );

  blocTest<ArtifactsMapBloc, ArtifactsMapState>(
    'a count update does not clear already-loaded artifacts',
    build: () => ArtifactsMapBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const ArtifactsMapSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      artifactsController.add([_artifact('1'), _artifact('2')]);
      await Future<void>.delayed(Duration.zero);
      unlocatedController.add(1);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) {
      final state = bloc.state as ArtifactsMapLoadSuccess;
      expect(state.artifacts.map((a) => a.id), ['1', '2']);
      expect(state.unlocatedCount, 1);
    },
  );

  blocTest<ArtifactsMapBloc, ArtifactsMapState>(
    'reports an empty map once the stream emits nothing',
    build: () => ArtifactsMapBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const ArtifactsMapSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      artifactsController.add([]);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) {
      expect((bloc.state as ArtifactsMapLoadSuccess).isEmpty, isTrue);
    },
  );

  blocTest<ArtifactsMapBloc, ArtifactsMapState>(
    'surfaces a stream error as a failure state instead of throwing',
    build: () => ArtifactsMapBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const ArtifactsMapSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      artifactsController.addError(Exception('db gone'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const ArtifactsMapLoadInProgress(),
      isA<ArtifactsMapLoadFailure>(),
    ],
  );

  test('cancels its subscriptions on close', () async {
    final bloc = ArtifactsMapBloc(repository: repository);
    bloc.add(const ArtifactsMapSubscriptionRequested());
    await Future<void>.delayed(Duration.zero);

    expect(artifactsController.hasListener, isTrue);
    expect(unlocatedController.hasListener, isTrue);

    await bloc.close();

    expect(artifactsController.hasListener, isFalse);
    expect(unlocatedController.hasListener, isFalse);
  });

  /// The map opened from inside an entry must ask the repository for that
  /// entry's finds, not filter a whole-dig result afterwards -- otherwise
  /// every pin in the dig is loaded to show two.
  group('scoped to one note', () {
    test('passes the noteId straight through to the repository', () async {
      when(
        () => repository.watchLocatedArtifacts(noteId: any(named: 'noteId')),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => repository.watchUnlocatedCount(noteId: any(named: 'noteId')),
      ).thenAnswer((_) => Stream.value(0));

      final bloc = ArtifactsMapBloc(repository: repository, noteId: 'n1')
        ..add(const ArtifactsMapSubscriptionRequested());
      addTearDown(bloc.close);
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.watchLocatedArtifacts(noteId: 'n1')).called(1);
      verify(() => repository.watchUnlocatedCount(noteId: 'n1')).called(1);
    });

    test('asks for everything when no note is given', () async {
      when(
        () => repository.watchLocatedArtifacts(noteId: any(named: 'noteId')),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => repository.watchUnlocatedCount(noteId: any(named: 'noteId')),
      ).thenAnswer((_) => Stream.value(0));

      final bloc = ArtifactsMapBloc(repository: repository)
        ..add(const ArtifactsMapSubscriptionRequested());
      addTearDown(bloc.close);
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.watchLocatedArtifacts(noteId: null)).called(1);
    });
  });
}
