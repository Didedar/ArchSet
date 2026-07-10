part of 'editor_bloc.dart';

sealed class EditorState extends Equatable {
  const EditorState();

  @override
  List<Object?> get props => [];
}

final class EditorIdle extends EditorState {
  const EditorIdle();
}

final class EditorSaveInProgress extends EditorState {
  const EditorSaveInProgress();
}

final class EditorSaveSuccess extends EditorState {
  const EditorSaveSuccess();
}

final class EditorDeleteInProgress extends EditorState {
  const EditorDeleteInProgress();
}

final class EditorDeleteSuccess extends EditorState {
  const EditorDeleteSuccess();
}

final class EditorAiRewriteInProgress extends EditorState {
  const EditorAiRewriteInProgress();
}

final class EditorAiRewriteSuccess extends EditorState {
  const EditorAiRewriteSuccess(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// [exceptionMessage] is null when the service simply returned no text
/// (widget shows the generic, localized "rewrite failed" message) and
/// set when an exception was thrown (widget shows the raw error text,
/// matching the original's unlocalized 'Error: $e' snackbar).
final class EditorAiRewriteFailure extends EditorState {
  const EditorAiRewriteFailure({this.exceptionMessage});

  final String? exceptionMessage;

  @override
  List<Object?> get props => [exceptionMessage];
}

final class EditorScanInProgress extends EditorState {
  const EditorScanInProgress();
}

final class EditorScanSuccess extends EditorState {
  const EditorScanSuccess(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// [message] is null when the failure came from a caught exception
/// (matches the original: logged only, no snackbar) and set when the
/// service returned no text (widget shows this message in a snackbar).
final class EditorScanFailure extends EditorState {
  const EditorScanFailure({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}
