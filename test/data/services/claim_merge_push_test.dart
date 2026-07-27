import 'dart:async';

import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/claim_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late _MockApiService apiService;
  late _MockConnectivity connectivity;

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

    final storageValues = installFakeSecureStorage();
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
}
