import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';

import '../../support/fake_secure_storage.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockConnectivity extends Mock implements Connectivity {}

/// Where the sync cursor comes from, and what happens when it lies.
///
/// The cursor is the "what changed since?" cutoff sent to the server. Two
/// ways it went wrong, both ending with an account that looked empty:
///
///  1. It was one global key, so signing into a second account on the same
///     device inherited the first account's cutoff. Everything older than
///     that -- including a dig site shared days earlier -- came back
///     "unchanged" and never arrived.
///  2. Even scoped correctly, a cutoff can outrun an invitation: once the
///     client has synced past the moment access was granted, no incremental
///     pull will ever mention that site again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ivan = 'ivan-id';
  const maria = 'maria-id';

  late AppDatabase database;
  late _MockApiService apiService;
  late _MockConnectivity connectivity;
  late Map<String, String> storage;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late List<Map<String, dynamic>> pushed;

  Map<String, dynamic> response({
    List<Map<String, dynamic>> folders = const [],
    List<String>? accessible,
  }) => {
    'notes': const [],
    'folders': folders,
    'artifacts': const [],
    'artifact_comments': const [],
    if (accessible != null) 'accessible_folder_ids': accessible,
    'sync_timestamp': DateTime.utc(2026, 8, 4, 12).toIso8601String(),
  };

  Map<String, dynamic> folderPayload(String id, String name) => {
    'id': id,
    'name': name,
    'color': '#E8B731',
    'updated_at': DateTime.utc(2026, 8, 3).toIso8601String(),
    'is_deleted': false,
  };

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    apiService = _MockApiService();
    connectivity = _MockConnectivity();
    connectivityController =
        StreamController<List<ConnectivityResult>>.broadcast();
    storage = installFakeSecureStorage();
    pushed = [];

    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => connectivityController.stream);
    when(() => apiService.checkHealth()).thenAnswer((_) async => true);
    when(() => apiService.post(any(), any())).thenAnswer((invocation) async {
      pushed.add(invocation.positionalArguments[1] as Map<String, dynamic>);
      return response();
    });
  });

  tearDown(() async {
    await connectivityController.close();
    await database.close();
  });

  SyncService buildService() => SyncService(
    apiService: apiService,
    database: database,
    connectivity: connectivity,
    storage: const FlutterSecureStorage(),
    retryBackoff: const [Duration.zero],
  );

  group('the cursor belongs to one account', () {
    test('a second account does not inherit the first account\'s cutoff', () async {
      storage['current_owner_id'] = ivan;
      final service = buildService();
      addTearDown(service.dispose);
      await service.sync();
      expect(pushed.single['last_sync_at'], isNull, reason: 'ivan starts fresh');

      // Ivan signs out, Maria signs in on the same phone.
      pushed.clear();
      storage['current_owner_id'] = maria;
      await service.sync();

      expect(
        pushed.single['last_sync_at'],
        isNull,
        reason: "maria asked the server what changed since ivan last looked, "
            'so everything older than that was reported as unchanged',
      );
    });

    test('the same account keeps its own cutoff between syncs', () async {
      storage['current_owner_id'] = ivan;
      final service = buildService();
      addTearDown(service.dispose);

      await service.sync();
      pushed.clear();
      await service.sync();

      expect(pushed.single['last_sync_at'], isNotNull);
    });

    test('switching back restores the earlier account\'s own cutoff', () async {
      storage['current_owner_id'] = ivan;
      final service = buildService();
      addTearDown(service.dispose);
      await service.sync();

      storage['current_owner_id'] = maria;
      await service.sync();

      pushed.clear();
      storage['current_owner_id'] = ivan;
      await service.sync();

      expect(pushed.single['last_sync_at'], isNotNull);
    });

    test('a cursor left by an older build is discarded, not adopted', () async {
      // Un-namespaced, so there is no telling whose it was.
      storage['last_sync_timestamp'] = DateTime.utc(2026, 8, 4).toIso8601String();
      storage['current_owner_id'] = maria;
      final service = buildService();
      addTearDown(service.dispose);

      await service.sync();

      expect(pushed.single['last_sync_at'], isNull);
      expect(storage['last_sync_timestamp'], isNull, reason: 'and removed');
    });
  });

  group('a dig site the device never received', () {
    setUp(() {
      storage['current_owner_id'] = maria;
    });

    test('is fetched by one full pull when the cutoff already outran it', () async {
      // Maria has synced before, so she has a cutoff...
      final service = buildService();
      addTearDown(service.dispose);
      await service.sync();
      pushed.clear();

      // ...and the server now says she may reach a site she has never seen.
      var call = 0;
      when(() => apiService.post(any(), any())).thenAnswer((invocation) async {
        pushed.add(invocation.positionalArguments[1] as Map<String, dynamic>);
        call++;
        // The incremental answer is empty: nothing *changed*, it only became
        // visible. Only a cutoff-free pull carries the site itself.
        return call == 1
            ? response(accessible: const ['f-site'])
            : response(
                folders: [folderPayload('f-site', 'Papka 1')],
                accessible: const ['f-site'],
              );
      });

      await service.sync();

      expect(pushed, hasLength(2), reason: 'one repair pull, not a loop');
      expect(pushed.last['last_sync_at'], isNull);

      final folders = await database.select(database.folders).get();
      expect(folders.map((f) => f.name), contains('Papka 1'));
    });

    test('no repair pull happens when everything reachable is already held', () async {
      when(() => apiService.post(any(), any())).thenAnswer((invocation) async {
        pushed.add(invocation.positionalArguments[1] as Map<String, dynamic>);
        return response(
          folders: [folderPayload('f-site', 'Papka 1')],
          accessible: const ['f-site'],
        );
      });
      final service = buildService();
      addTearDown(service.dispose);

      await service.sync();
      pushed.clear();
      await service.sync();

      expect(pushed, hasLength(1), reason: 'nothing missing, nothing to repair');
    });

    test('an older server that omits the field forces no full pull', () async {
      final service = buildService();
      addTearDown(service.dispose);

      await service.sync();
      pushed.clear();
      await service.sync();

      expect(pushed, hasLength(1));
    });
  });
}
