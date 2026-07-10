import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/presentation/notes/bloc/notes_bloc.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

Note _note(String id) => Note(
      id: id,
      title: 'Title $id',
      content: 'Content $id',
      date: DateTime(2026, 1, 1),
      isDeleted: false,
    );

void main() {
  late _MockNotesRepository repository;
  late StreamController<List<Note>> allNotesController;
  late StreamController<List<Note>> folderNotesController;

  setUp(() {
    repository = _MockNotesRepository();
    allNotesController = StreamController<List<Note>>.broadcast();
    folderNotesController = StreamController<List<Note>>.broadcast();
    when(() => repository.watchAllNotes())
        .thenAnswer((_) => allNotesController.stream);
    when(() => repository.watchNotesInFolder('folder-1'))
        .thenAnswer((_) => folderNotesController.stream);
  });

  tearDown(() {
    allNotesController.close();
    folderNotesController.close();
  });

  blocTest<NotesBloc, NotesState>(
    'subscribes to all notes when folderId is null',
    build: () => NotesBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const NotesSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      allNotesController.add([_note('1'), _note('2')]);
    },
    expect: () => [
      const NotesLoadInProgress(),
      NotesLoadSuccess([_note('1'), _note('2')]),
    ],
  );

  blocTest<NotesBloc, NotesState>(
    'subscribes to notes-in-folder when folderId is given',
    build: () => NotesBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const NotesSubscriptionRequested(folderId: 'folder-1'));
      await Future<void>.delayed(Duration.zero);
      folderNotesController.add([_note('3')]);
    },
    expect: () => [
      const NotesLoadInProgress(),
      NotesLoadSuccess([_note('3')]),
    ],
  );

  blocTest<NotesBloc, NotesState>(
    'retargeting the subscription cancels the previous one (restartable)',
    build: () => NotesBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const NotesSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const NotesSubscriptionRequested(folderId: 'folder-1'));
      await Future<void>.delayed(Duration.zero);
      // Late event on the abandoned "all notes" stream must not resurface.
      allNotesController.add([_note('stale')]);
      await Future<void>.delayed(Duration.zero);
      folderNotesController.add([_note('3')]);
    },
    // Only one NotesLoadInProgress: the second request would emit an
    // identical state, which flutter_bloc's Emitter suppresses (a state
    // equal to the current one is not re-emitted).
    expect: () => [
      const NotesLoadInProgress(),
      NotesLoadSuccess([_note('3')]),
    ],
  );

  blocTest<NotesBloc, NotesState>(
    'NotesDeleteRequested calls repository.deleteNote',
    setUp: () => when(() => repository.deleteNote('1'))
        .thenAnswer((_) async {}),
    build: () => NotesBloc(repository: repository),
    act: (bloc) => bloc.add(const NotesDeleteRequested('1')),
    verify: (_) {
      verify(() => repository.deleteNote('1')).called(1);
    },
  );

  blocTest<NotesBloc, NotesState>(
    'NotesMoveToFolderRequested calls repository.moveNoteToFolder',
    setUp: () => when(() => repository.moveNoteToFolder('1', 'folder-2'))
        .thenAnswer((_) async {}),
    build: () => NotesBloc(repository: repository),
    act: (bloc) =>
        bloc.add(const NotesMoveToFolderRequested('1', 'folder-2')),
    verify: (_) {
      verify(() => repository.moveNoteToFolder('1', 'folder-2')).called(1);
    },
  );

  test('initial state is NotesInitial', () {
    expect(NotesBloc(repository: repository).state, const NotesInitial());
  });
}
