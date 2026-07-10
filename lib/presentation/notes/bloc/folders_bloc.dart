import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repository/notes_repository.dart';

part 'folders_event.dart';
part 'folders_state.dart';

/// Combines [NotesRepository]'s three folder-related streams (folders,
/// per-folder note counts, all-notes count) into one [FoldersLoadSuccess].
class FoldersBloc extends Bloc<FoldersEvent, FoldersState> {
  FoldersBloc({required NotesRepository repository})
      : _repository = repository,
        super(const FoldersInitial()) {
    on<FoldersSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<FoldersCreateRequested>(_onCreateRequested, transformer: droppable());
    on<FoldersDeleteRequested>(_onDeleteRequested, transformer: droppable());
    on<_FoldersUpdated>(_onFoldersUpdated, transformer: sequential());
    on<_FolderCountsUpdated>(_onFolderCountsUpdated, transformer: sequential());
    on<_AllNotesCountUpdated>(
      _onAllNotesCountUpdated,
      transformer: sequential(),
    );
  }

  final NotesRepository _repository;
  StreamSubscription<List<Folder>>? _foldersSub;
  StreamSubscription<Map<String, int>>? _countsSub;
  StreamSubscription<int>? _allNotesCountSub;

  Future<void> _onSubscriptionRequested(
    FoldersSubscriptionRequested event,
    Emitter<FoldersState> emit,
  ) async {
    emit(const FoldersLoadInProgress());
    await _foldersSub?.cancel();
    await _countsSub?.cancel();
    await _allNotesCountSub?.cancel();
    _foldersSub = _repository
        .watchAllFolders()
        .listen((folders) => add(_FoldersUpdated(folders)));
    _countsSub = _repository
        .watchFolderNoteCounts()
        .listen((counts) => add(_FolderCountsUpdated(counts)));
    _allNotesCountSub = _repository
        .watchAllNotesCount()
        .listen((count) => add(_AllNotesCountUpdated(count)));
  }

  Future<void> _onCreateRequested(
    FoldersCreateRequested event,
    Emitter<FoldersState> emit,
  ) async {
    await _repository.createFolder(event.folder);
  }

  Future<void> _onDeleteRequested(
    FoldersDeleteRequested event,
    Emitter<FoldersState> emit,
  ) async {
    await _repository.deleteFolder(event.folderId);
  }

  void _onFoldersUpdated(_FoldersUpdated event, Emitter<FoldersState> emit) {
    emit(_currentSuccess.copyWith(folders: event.folders));
  }

  void _onFolderCountsUpdated(
    _FolderCountsUpdated event,
    Emitter<FoldersState> emit,
  ) {
    emit(_currentSuccess.copyWith(folderCounts: event.counts));
  }

  void _onAllNotesCountUpdated(
    _AllNotesCountUpdated event,
    Emitter<FoldersState> emit,
  ) {
    emit(_currentSuccess.copyWith(allNotesCount: event.count));
  }

  FoldersLoadSuccess get _currentSuccess {
    final current = state;
    return current is FoldersLoadSuccess ? current : const FoldersLoadSuccess();
  }

  @override
  Future<void> close() async {
    await _foldersSub?.cancel();
    await _countsSub?.cancel();
    await _allNotesCountSub?.cancel();
    return super.close();
  }
}
