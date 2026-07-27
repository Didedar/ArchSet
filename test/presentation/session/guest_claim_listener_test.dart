import 'dart:async';

import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/auth_service.dart' show AuthUser;
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';
import 'package:archset_r2/presentation/session/guest_claim_listener.dart';
import 'package:archset_r2/presentation/sync/bloc/sync_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _MockSessionCubit extends MockCubit<AppSession> implements SessionCubit {}

class _MockSyncService extends Mock implements SyncService {}

/// D5: [GuestClaimListener] is the widget that actually wires
/// [GuestClaimCoordinator] into the running app -- it must claim guest data
/// and request a sync whenever the session it observes transitions into
/// [SessionAuthenticated], and it must be able to read [CoreDependencies],
/// [SessionCubit], and [SyncBloc] from wherever it's mounted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late CoreDependencies coreDependencies;
  late _MockSessionCubit sessionCubit;
  late StreamController<AppSession> sessionController;
  late _MockSyncService syncService;
  late SyncBloc syncBloc;

  final user = AuthUser(
    id: 'user-1',
    email: 'user-1@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: 'offline-note',
            title: 'Offline note',
            content: 'Content',
            date: DateTime(2026, 1, 1),
          ),
        );

    coreDependencies = CoreDependencies(
      database: database,
      secureStorage: const FlutterSecureStorage(),
      logger: Logger(),
    );

    sessionController = StreamController<AppSession>.broadcast();
    sessionCubit = _MockSessionCubit();
    whenListen(
      sessionCubit,
      sessionController.stream,
      initialState: const SessionGuest(),
    );

    syncService = _MockSyncService();
    when(
      () => syncService.sync(),
    ).thenAnswer((_) async => SyncResult(status: SyncStatus.success));
    syncBloc = SyncBloc(service: syncService);
  });

  tearDown(() async {
    await sessionController.close();
    await syncBloc.close();
    await database.close();
  });

  Future<Note> readNote(String id) => (database.select(
    database.notes,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<void> pumpListener(WidgetTester tester) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [Provider<CoreDependencies>.value(value: coreDependencies)],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SessionCubit>.value(value: sessionCubit),
            BlocProvider<SyncBloc>.value(value: syncBloc),
          ],
          child: const GuestClaimListener(child: SizedBox()),
        ),
      ),
    );
  }

  testWidgets(
    'claims guest data for the account and requests a sync when the '
    'session transitions to SessionAuthenticated',
    (tester) async {
      await pumpListener(tester);

      sessionController.add(SessionAuthenticated(user));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final note = await readNote('offline-note');
      expect(note.ownerKey, 'user-1');
      expect(note.pendingSync, isTrue);
      verify(() => syncService.sync()).called(1);
    },
  );

  testWidgets(
    'a transition to SessionUnauthenticated is ignored: no claim, no sync '
    'dispatch',
    (tester) async {
      await pumpListener(tester);

      sessionController.add(const SessionUnauthenticated());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final note = await readNote('offline-note');
      expect(note.ownerKey, isNull);
      expect(note.pendingSync, isFalse);
      verifyNever(() => syncService.sync());
    },
  );
}
