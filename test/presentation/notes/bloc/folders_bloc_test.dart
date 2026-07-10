import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/presentation/notes/bloc/folders_bloc.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

Folder _folder(String id) => Folder(
      id: id,
      name: 'Folder $id',
      color: '#E8B731',
      createdAt: DateTime(2026, 1, 1),
      isDeleted: false,
    );

void main() {
  late _MockNotesRepository repository;
  late StreamController<List<Folder>> foldersController;
  late StreamController<Map<String, int>> countsController;
  late StreamController<int> allNotesCountController;

  setUpAll(() => registerFallbackValue(_folder('fallback')));

  setUp(() {
    repository = _MockNotesRepository();
    foldersController = StreamController<List<Folder>>.broadcast();
    countsController = StreamController<Map<String, int>>.broadcast();
    allNotesCountController = StreamController<int>.broadcast();
    when(() => repository.watchAllFolders())
        .thenAnswer((_) => foldersController.stream);
    when(() => repository.watchFolderNoteCounts())
        .thenAnswer((_) => countsController.stream);
    when(() => repository.watchAllNotesCount())
        .thenAnswer((_) => allNotesCountController.stream);
  });

  tearDown(() {
    foldersController.close();
    countsController.close();
    allNotesCountController.close();
  });

  blocTest<FoldersBloc, FoldersState>(
    'combines all three streams into one FoldersLoadSuccess',
    build: () => FoldersBloc(repository: repository),
    act: (bloc) async {
      bloc.add(const FoldersSubscriptionRequested());
      await Future<void>.delayed(Duration.zero);
      foldersController.add([_folder('1')]);
      await Future<void>.delayed(Duration.zero);
      countsController.add({'1': 3});
      await Future<void>.delayed(Duration.zero);
      allNotesCountController.add(7);
    },
    expect: () => [
      const FoldersLoadInProgress(),
      FoldersLoadSuccess(folders: [_folder('1')]),
      FoldersLoadSuccess(folders: [_folder('1')], folderCounts: const {'1': 3}),
      FoldersLoadSuccess(
        folders: [_folder('1')],
        folderCounts: const {'1': 3},
        allNotesCount: 7,
      ),
    ],
  );

  blocTest<FoldersBloc, FoldersState>(
    'FoldersCreateRequested calls repository.createFolder',
    setUp: () => when(() => repository.createFolder(any()))
        .thenAnswer((_) async {}),
    build: () => FoldersBloc(repository: repository),
    act: (bloc) => bloc.add(FoldersCreateRequested(_folder('new'))),
    verify: (_) {
      verify(() => repository.createFolder(_folder('new'))).called(1);
    },
  );

  blocTest<FoldersBloc, FoldersState>(
    'FoldersDeleteRequested calls repository.deleteFolder',
    setUp: () => when(() => repository.deleteFolder('1'))
        .thenAnswer((_) async {}),
    build: () => FoldersBloc(repository: repository),
    act: (bloc) => bloc.add(const FoldersDeleteRequested('1')),
    verify: (_) {
      verify(() => repository.deleteFolder('1')).called(1);
    },
  );

  test('initial state is FoldersInitial', () {
    expect(FoldersBloc(repository: repository).state, const FoldersInitial());
  });
}
