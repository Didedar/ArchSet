import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/auth_service.dart' show AuthUser;
import 'package:archset_r2/data/services/claim_service.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';
import 'package:archset_r2/presentation/session/guest_claim_coordinator.dart';
import 'package:archset_r2/presentation/sync/bloc/sync_bloc.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncBloc extends Mock implements SyncBloc {}

/// D2: on a transition into [SessionAuthenticated], [GuestClaimCoordinator]
/// hands every unclaimed local row to the freshly authenticated account (via
/// [ClaimService]) and then asks [SyncBloc] to push them. Guest/unauthenticated
/// sessions must never claim or trigger a sync -- there is no account yet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const SyncRequested());
  });

  late AppDatabase database;
  late _MockSyncBloc syncBloc;
  late GuestClaimCoordinator coordinator;

  AuthUser user(String id) => AuthUser(
    id: id,
    email: '$id@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    syncBloc = _MockSyncBloc();
    when(() => syncBloc.add(any())).thenReturn(null);
    coordinator = GuestClaimCoordinator(
      claimService: ClaimService(database),
      syncBloc: syncBloc,
    );
  });

  tearDown(() => database.close());

  Future<void> insertGuestNote(String id) => database
      .into(database.notes)
      .insert(
        NotesCompanion.insert(
          id: id,
          title: 'Title $id',
          content: 'Content $id',
          date: DateTime(2026, 1, 1),
        ),
      );

  Future<Note> readNote(String id) => (database.select(
    database.notes,
  )..where((t) => t.id.equals(id))).getSingle();

  group('GuestClaimCoordinator', () {
    test('SessionAuthenticated claims guest data for the user and dispatches '
        'SyncRequested', () async {
      await insertGuestNote('note-1');

      await coordinator.handleSession(SessionAuthenticated(user('user-1')));

      final note = await readNote('note-1');
      expect(note.ownerKey, 'user-1');
      expect(note.pendingSync, isTrue);
      verify(() => syncBloc.add(const SyncRequested())).called(1);
    });

    test('SessionGuest is ignored: no claim, no sync dispatch', () async {
      await insertGuestNote('note-1');

      await coordinator.handleSession(const SessionGuest());

      final note = await readNote('note-1');
      expect(note.ownerKey, isNull);
      expect(note.pendingSync, isFalse);
      verifyNever(() => syncBloc.add(any()));
    });

    test(
      'SessionUnauthenticated is ignored: no claim, no sync dispatch',
      () async {
        await insertGuestNote('note-1');

        await coordinator.handleSession(const SessionUnauthenticated());

        final note = await readNote('note-1');
        expect(note.ownerKey, isNull);
        expect(note.pendingSync, isFalse);
        verifyNever(() => syncBloc.add(any()));
      },
    );
  });
}
