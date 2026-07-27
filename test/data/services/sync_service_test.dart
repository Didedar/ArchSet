import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';

import '../../support/fake_app_database.dart';
import '../../support/fake_secure_storage.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockConnectivity extends Mock implements Connectivity {}

/// C2/C3: the sync engine now (a) selects dirty rows by `pendingSync` instead
/// of an `updatedAt` heuristic and clears the flag only for the rows it just
/// pushed, and (b) gates every sync behind a reachability probe + auth check,
/// retrying a failed push with backoff before giving up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService', () {
    late AppDatabase database;
    late _MockApiService apiService;
    late _MockConnectivity connectivity;
    late Map<String, String> storageValues;
    late StreamController<List<ConnectivityResult>> connectivityController;

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
      connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();

      storageValues = installFakeSecureStorage();
      storageValues['current_owner_id'] = 'user-1';

      when(
        () => connectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => connectivityController.stream);
      when(() => apiService.checkHealth()).thenAnswer((_) async => true);
      when(
        () => apiService.post(any(), any()),
      ).thenAnswer((_) async => emptyPullResponse());
    });

    tearDown(() async {
      await connectivityController.close();
      await database.close();
    });

    SyncService buildService({List<Duration>? retryBackoff}) {
      return SyncService(
        apiService: apiService,
        database: database,
        connectivity: connectivity,
        storage: const FlutterSecureStorage(),
        retryBackoff: retryBackoff ?? const [Duration.zero],
      );
    }

    Future<void> insertNote(
      String id, {
      required bool pendingSync,
      DateTime? updatedAt,
    }) async {
      await database
          .into(database.notes)
          .insert(
            Note(
              id: id,
              title: 'Title $id',
              content: 'Content $id',
              date: DateTime(2026, 1, 1),
              updatedAt: updatedAt,
              isDeleted: false,
              pendingSync: pendingSync,
            ),
          );
    }

    Future<void> insertFolder(
      String id, {
      required bool pendingSync,
      DateTime? updatedAt,
    }) async {
      await database
          .into(database.folders)
          .insert(
            Folder(
              id: id,
              name: 'Folder $id',
              color: '#E8B731',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: updatedAt,
              isDeleted: false,
              pendingSync: pendingSync,
            ),
          );
    }

    Future<Note> readNote(String id) =>
        (database.select(database.notes)
          ..where((t) => t.id.equals(id))).getSingle();

    Future<Folder> readFolder(String id) =>
        (database.select(database.folders)
          ..where((t) => t.id.equals(id))).getSingle();

    test(
      'only pendingSync rows are pushed; pushed rows clear the flag and '
      'clean rows are left untouched',
      () async {
        final dirtyNoteUpdatedAt = DateTime(2026, 2, 1);
        await insertNote(
          'dirty-note',
          pendingSync: true,
          updatedAt: dirtyNoteUpdatedAt,
        );
        await insertNote(
          'clean-note',
          pendingSync: false,
          updatedAt: DateTime(2026, 1, 15),
        );
        final dirtyFolderUpdatedAt = DateTime(2026, 2, 2);
        await insertFolder(
          'dirty-folder',
          pendingSync: true,
          updatedAt: dirtyFolderUpdatedAt,
        );
        await insertFolder(
          'clean-folder',
          pendingSync: false,
          updatedAt: DateTime(2026, 1, 16),
        );

        late Map<String, dynamic> pushedPayload;
        when(() => apiService.post(any(), any())).thenAnswer((invocation) async {
          pushedPayload =
              invocation.positionalArguments[1] as Map<String, dynamic>;
          return emptyPullResponse();
        });

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.success);

        final notesSent = pushedPayload['notes'] as List;
        final foldersSent = pushedPayload['folders'] as List;
        expect(notesSent, hasLength(1));
        expect(notesSent.single['id'], 'dirty-note');
        expect(foldersSent, hasLength(1));
        expect(foldersSent.single['id'], 'dirty-folder');

        expect((await readNote('dirty-note')).pendingSync, isFalse);
        expect((await readFolder('dirty-folder')).pendingSync, isFalse);

        // Rows that were never dirty are not part of the payload and stay
        // exactly as they were.
        final cleanNote = await readNote('clean-note');
        expect(cleanNote.pendingSync, isFalse);
        expect(cleanNote.updatedAt, DateTime(2026, 1, 15));
        final cleanFolder = await readFolder('clean-folder');
        expect(cleanFolder.pendingSync, isFalse);
        expect(cleanFolder.updatedAt, DateTime(2026, 1, 16));
      },
    );

    test(
      'a row re-edited mid-round-trip (updatedAt changed after being read) '
      'keeps its pendingSync flag set',
      () async {
        await insertNote(
          'racy-note',
          pendingSync: true,
          updatedAt: DateTime(2026, 3, 1),
        );

        when(() => apiService.post(any(), any())).thenAnswer((_) async {
          // Simulate the note being edited again while the push is in
          // flight: bump updatedAt and pendingSync after the server already
          // has the payload, but before the client clears the flag.
          await (database.update(database.notes)
                ..where((t) => t.id.equals('racy-note')))
              .write(
                NotesCompanion(
                  updatedAt: Value(DateTime(2026, 3, 2)),
                  pendingSync: const Value(true),
                ),
              );
          return emptyPullResponse();
        });

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.success);
        final row = await readNote('racy-note');
        expect(row.pendingSync, isTrue);
        expect(row.updatedAt, DateTime(2026, 3, 2));
      },
    );

    test(
      'unreachable server (checkHealth false) returns offline and never '
      'posts',
      () async {
        when(() => apiService.checkHealth()).thenAnswer((_) async => false);

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.offline);
        verifyNever(() => apiService.post(any(), any()));
      },
    );

    test(
      'no current_owner_id (guest) returns idle and never posts',
      () async {
        storageValues.remove('current_owner_id');

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.idle);
        verifyNever(() => apiService.post(any(), any()));
      },
    );

    test('a push that fails once then succeeds retries and reports success', () async {
      var calls = 0;
      when(() => apiService.post(any(), any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw ApiException(500, 'temporary failure');
        }
        return emptyPullResponse();
      });

      final service = buildService(); // retryBackoff: [Duration.zero]
      final result = await service.sync();

      expect(result.status, SyncStatus.success);
      expect(calls, 2);
      verify(() => apiService.post(any(), any())).called(2);
    });

    test(
      'a push that always fails gives up after exhausting the retry '
      'backoff and reports error',
      () async {
        when(
          () => apiService.post(any(), any()),
        ).thenThrow(ApiException(500, 'permanent failure'));

        final service = buildService(
          retryBackoff: const [Duration.zero, Duration.zero],
        );
        final result = await service.sync();

        expect(result.status, SyncStatus.error);
        verify(() => apiService.post(any(), any())).called(3);
      },
    );

    test(
      'regaining connectivity while authenticated triggers a flush sync',
      () async {
        final service = buildService();
        addTearDown(service.dispose);

        service.startMonitoring();
        connectivityController.add([ConnectivityResult.wifi]);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(() => apiService.post(any(), any())).called(1);
      },
    );
  });

  group('ApiService.checkHealth', () {
    test(
      'probes the root /health path (not under /api/v1) and returns true '
      'on HTTP 200',
      () async {
        Uri? requestedUri;
        final client = MockClient((request) async {
          requestedUri = request.url;
          return http.Response('', 200);
        });

        final api = ApiService(
          authService: AuthService(database: FakeAppDatabase()),
          client: client,
        );
        addTearDown(api.dispose);

        final healthy = await api.checkHealth();

        expect(healthy, isTrue);
        expect(requestedUri, isNotNull);
        expect(requestedUri!.path, '/health');
        expect(requestedUri!.toString(), isNot(contains('/api/v1')));
      },
    );

    test('returns false on a non-200 response', () async {
      final api = ApiService(
        authService: AuthService(database: FakeAppDatabase()),
        client: MockClient((request) async => http.Response('', 503)),
      );
      addTearDown(api.dispose);

      expect(await api.checkHealth(), isFalse);
    });

    test('returns false instead of throwing on a network error', () async {
      final api = ApiService(
        authService: AuthService(database: FakeAppDatabase()),
        client: MockClient((request) async {
          throw const SocketException('no route to host');
        }),
      );
      addTearDown(api.dispose);

      expect(await api.checkHealth(), isFalse);
    });
  });
}
