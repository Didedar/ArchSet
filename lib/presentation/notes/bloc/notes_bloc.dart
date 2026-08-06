import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repository/notes_repository.dart';

part 'notes_event.dart';
part 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc({required NotesRepository repository})
    : _repository = repository,
      super(const NotesInitial()) {
    on<NotesSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<NotesDeleteRequested>(_onDeleteRequested, transformer: droppable());
    on<NotesMoveToFolderRequested>(
      _onMoveToFolderRequested,
      transformer: droppable(),
    );
  }

  final NotesRepository _repository;

  Future<void> _onSubscriptionRequested(
    NotesSubscriptionRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(const NotesLoadInProgress());
    final stream = event.folderId == null
        ? _repository.watchAllNotes()
        : _repository.watchNotesInFolder(event.folderId);
    await emit.forEach<List<Note>>(
      stream,
      onData: (notes) => NotesLoadSuccess(notes),
      onError: (error, stackTrace) => NotesLoadFailure(error.toString()),
    );
  }

  Future<void> _onDeleteRequested(
    NotesDeleteRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.deleteNote(event.noteId);
  }

  Future<void> _onMoveToFolderRequested(
    NotesMoveToFolderRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.moveNoteToFolder(event.noteId, event.folderId);
  }
}
