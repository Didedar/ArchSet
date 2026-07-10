part of 'sync_bloc.dart';

sealed class SyncEvent {
  const SyncEvent();
}

/// Starts connectivity monitoring and subscribes to the service's status
/// and result streams. Dispatched once, at app start.
final class SyncMonitoringStarted extends SyncEvent {
  const SyncMonitoringStarted();
}

/// Manual sync trigger (e.g. a "sync now" button).
final class SyncRequested extends SyncEvent {
  const SyncRequested();
}

final class _SyncStatusReceived extends SyncEvent {
  const _SyncStatusReceived(this.status);
  final SyncStatus status;
}

final class _SyncResultReceived extends SyncEvent {
  const _SyncResultReceived(this.result);
  final SyncResult result;
}
