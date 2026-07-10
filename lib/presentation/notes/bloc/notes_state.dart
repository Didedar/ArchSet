part of 'notes_bloc.dart';

sealed class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object?> get props => [];
}

final class NotesInitial extends NotesState {
  const NotesInitial();
}

final class NotesLoadInProgress extends NotesState {
  const NotesLoadInProgress();
}

final class NotesLoadSuccess extends NotesState {
  const NotesLoadSuccess(this.notes);

  final List<Note> notes;

  @override
  List<Object?> get props => [notes];
}

final class NotesLoadFailure extends NotesState {
  const NotesLoadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
