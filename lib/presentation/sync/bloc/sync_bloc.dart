import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/sync_service.dart';

part 'sync_event.dart';
part 'sync_state.dart';

/// Thin bridge over [SyncService]'s own status/result streams -- the
/// service already owns the actual sync/connectivity logic, this BLoC
/// just mirrors it into states the UI can consume.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc({required SyncService service})
    : _service = service,
      super(const SyncIdle()) {
    on<SyncMonitoringStarted>(_onMonitoringStarted, transformer: restartable());
    on<SyncRequested>(_onSyncRequested, transformer: droppable());
    on<_SyncStatusReceived>(
      (event, emit) => emit(_mapStatus(event.status)),
      transformer: sequential(),
    );
    on<_SyncResultReceived>(
      (event, emit) => emit(_mapResult(event.result)),
      transformer: sequential(),
    );
  }

  final SyncService _service;
  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<SyncResult>? _resultSub;

  Future<void> _onMonitoringStarted(
    SyncMonitoringStarted event,
    Emitter<SyncState> emit,
  ) async {
    _service.startMonitoring();
    _statusSub = _service.statusStream.listen(
      (status) => add(_SyncStatusReceived(status)),
    );
    _resultSub = _service.resultStream.listen(
      (result) => add(_SyncResultReceived(result)),
    );
  }

  Future<void> _onSyncRequested(
    SyncRequested event,
    Emitter<SyncState> emit,
  ) async {
    await _service.sync();
  }

  SyncState _mapStatus(SyncStatus status) {
    return switch (status) {
      SyncStatus.idle => const SyncIdle(),
      SyncStatus.syncing => const SyncInProgress(),
      SyncStatus.offline => const SyncOffline(),
      // success/error carry details only available on the result stream.
      SyncStatus.success || SyncStatus.error => state,
    };
  }

  SyncState _mapResult(SyncResult result) {
    return switch (result.status) {
      SyncStatus.success => SyncSuccess(result),
      SyncStatus.error => SyncFailure(result.errorMessage ?? 'Unknown error'),
      _ => state,
    };
  }

  @override
  Future<void> close() async {
    await _statusSub?.cancel();
    await _resultSub?.cancel();
    return super.close();
  }
}
