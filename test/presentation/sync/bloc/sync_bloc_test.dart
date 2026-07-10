import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/presentation/sync/bloc/sync_bloc.dart';

class _MockSyncService extends Mock implements SyncService {}

void main() {
  late _MockSyncService service;
  late StreamController<SyncStatus> statusController;
  late StreamController<SyncResult> resultController;

  setUp(() {
    service = _MockSyncService();
    statusController = StreamController<SyncStatus>.broadcast();
    resultController = StreamController<SyncResult>.broadcast();
    when(() => service.statusStream).thenAnswer((_) => statusController.stream);
    when(() => service.resultStream).thenAnswer((_) => resultController.stream);
    when(() => service.startMonitoring()).thenReturn(null);
  });

  tearDown(() {
    statusController.close();
    resultController.close();
  });

  blocTest<SyncBloc, SyncState>(
    'starts monitoring and mirrors syncing/offline from the status stream',
    build: () => SyncBloc(service: service),
    act: (bloc) async {
      bloc.add(const SyncMonitoringStarted());
      await Future<void>.delayed(Duration.zero);
      statusController.add(SyncStatus.syncing);
      await Future<void>.delayed(Duration.zero);
      statusController.add(SyncStatus.offline);
    },
    expect: () => [const SyncInProgress(), const SyncOffline()],
    verify: (_) {
      verify(() => service.startMonitoring()).called(1);
    },
  );

  blocTest<SyncBloc, SyncState>(
    'mirrors a successful result from the result stream',
    build: () => SyncBloc(service: service),
    act: (bloc) async {
      bloc.add(const SyncMonitoringStarted());
      await Future<void>.delayed(Duration.zero);
      resultController.add(SyncResult(status: SyncStatus.success, notesUploaded: 2));
    },
    expect: () => [
      isA<SyncSuccess>().having((s) => s.result.notesUploaded, 'notesUploaded', 2),
    ],
  );

  blocTest<SyncBloc, SyncState>(
    'mirrors a failed result from the result stream',
    build: () => SyncBloc(service: service),
    act: (bloc) async {
      bloc.add(const SyncMonitoringStarted());
      await Future<void>.delayed(Duration.zero);
      resultController.add(
        SyncResult(status: SyncStatus.error, errorMessage: 'boom'),
      );
    },
    expect: () => [const SyncFailure('boom')],
  );

  blocTest<SyncBloc, SyncState>(
    'SyncRequested calls sync() on the service',
    setUp: () => when(() => service.sync()).thenAnswer(
      (_) async => SyncResult(status: SyncStatus.success),
    ),
    build: () => SyncBloc(service: service),
    act: (bloc) => bloc.add(const SyncRequested()),
    verify: (_) {
      verify(() => service.sync()).called(1);
    },
  );

  test('initial state is SyncIdle', () {
    expect(SyncBloc(service: service).state, const SyncIdle());
  });
}
