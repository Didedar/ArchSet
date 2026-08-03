import 'dart:async';

import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/claim_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_secure_storage.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockConnectivity extends Mock implements Connectivity {}

/// D4: existing-account merge -- a note claimed from a guest reaches the
/// push payload like any other pendingSync row, so it merges into the
/// account's existing data on the server.
///
/// No backend change is required for this: `SyncService.sync_notes` (see
/// `backend/app/services/sync_service.py`) already looks up each incoming
/// note by `(id, user_id)` scoped to the *authenticated* (JWT/server-stamped)
/// user. A claimed note's id is new under that user_id, so it inserts as a
/// brand new row; an id that already exists for that user is merged via
/// "last write wins" on `updated_at`. Either way this is a plain
/// insert-if-unknown / LWW-if-known union merge, so claiming locally and
/// then syncing is sufficient to fold a guest note into an existing account
/// -- nothing server-side needs to special-case a "claimed" row.
///
/// The `cross-account leak fix` group below is the regression test for a
/// critical bug: nothing used to stamp `ownerKey` on write, so a previous
/// account's still-dirty rows on a shared device had `ownerKey == null`
/// exactly like a genuine unclaimed guest row, and were indistinguishable
/// from one -- `ClaimService` would sweep them into the *new* account and
/// `SyncService` would push them to the wrong Postgres account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late _MockApiService apiService;
  late _MockConnectivity connectivity;
  late Map<String, String> storageValues;

  Map<String, dynamic> emptyPullResponse() => {
    'notes': [],
    'folders': [],
    'artifacts': [],
    'artifact_comments': [],
    'sync_timestamp': DateTime.now().toIso8601String(),
  };

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    apiService = _MockApiService();
    connectivity = _MockConnectivity();

    storageValues = installFakeSecureStorage();
    storageValues['current_owner_id'] = 'user-1';

    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(() => apiService.checkHealth()).thenAnswer((_) async => true);
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

  test(
    'a note claimed from a guest is included in the next push payload',
    () async {
      late Map<String, dynamic> capturedPayload;
      when(() => apiService.post('/sync', any())).thenAnswer((
        invocation,
      ) async {
        capturedPayload =
            invocation.positionalArguments[1] as Map<String, dynamic>;
        return emptyPullResponse();
      });

      await insertGuestNote('guest-uuid-abc');
      await ClaimService(database).claimGuestData('user-1');

      final sync = SyncService(
        apiService: apiService,
        database: database,
        connectivity: connectivity,
      );

      final result = await sync.sync();

      expect(result.status, SyncStatus.success);
      final notesSent = capturedPayload['notes'] as List;
      expect(
        notesSent,
        contains(
          isA<Map<String, dynamic>>().having(
            (n) => n['id'],
            'id',
            'guest-uuid-abc',
          ),
        ),
      );
    },
  );

  group('cross-account leak fix', () {
    test("claiming for user-b never sweeps user-a's still-dirty note into the "
        'push payload -- only the freshly claimed guest note syncs, under '
        'user-b', () async {
      // user-a has a locally-dirty (unsynced) note left behind on this
      // shared device -- e.g. they edited it offline, then signed out
      // before it ever reached the server.
      await database
          .into(database.notes)
          .insert(
            NotesCompanion.insert(
              id: 'user-a-note',
              title: 'User A secret',
              content: 'Content A',
              date: DateTime(2026, 1, 1),
              ownerKey: const Value('user-a'),
              pendingSync: const Value(true),
            ),
          );
      // A genuine unclaimed guest note created before user-b signed in.
      await insertGuestNote('guest-uuid-xyz');

      // user-b signs in on this device.
      storageValues['current_owner_id'] = 'user-b';

      late Map<String, dynamic> capturedPayload;
      when(() => apiService.post('/sync', any())).thenAnswer((
        invocation,
      ) async {
        capturedPayload =
            invocation.positionalArguments[1] as Map<String, dynamic>;
        return emptyPullResponse();
      });

      await ClaimService(database).claimGuestData('user-b');

      final sync = SyncService(
        apiService: apiService,
        database: database,
        connectivity: connectivity,
      );
      final result = await sync.sync();

      expect(result.status, SyncStatus.success);

      final sentIds = (capturedPayload['notes'] as List)
          .map((n) => (n as Map)['id'])
          .toList();
      expect(sentIds, isNot(contains('user-a-note')));
      expect(sentIds, contains('guest-uuid-xyz'));

      final userANote = await (database.select(
        database.notes,
      )..where((t) => t.id.equals('user-a-note'))).getSingle();
      expect(userANote.ownerKey, 'user-a');

      final claimedGuestNote = await (database.select(
        database.notes,
      )..where((t) => t.id.equals('guest-uuid-xyz'))).getSingle();
      expect(claimedGuestNote.ownerKey, 'user-b');
    });
  });
}
