part of 'sync_bloc.dart';

sealed class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

final class SyncIdle extends SyncState {
  const SyncIdle();
}

final class SyncInProgress extends SyncState {
  const SyncInProgress();
}

final class SyncSuccess extends SyncState {
  const SyncSuccess(this.result);

  final SyncResult result;

  @override
  List<Object?> get props => [result];
}

final class SyncFailure extends SyncState {
  const SyncFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class SyncOffline extends SyncState {
  const SyncOffline();
}
