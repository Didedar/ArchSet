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
import 'package:archset_r2/data/current_owner_holder.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';

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
    // The account every test is signed in as unless a test overrides
    // 'current_owner_id' directly. Used as the default owner for rows
    // inserted via the [insertNote]/[insertFolder] helpers below, so
    // existing "this dirty row gets pushed" tests keep behaving exactly as
    // before now that the push query also filters by owner.
    const ownerId = 'user-1';

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

    /// Like [emptyPullResponse] but with a caller-supplied `notes` payload,
    /// for tests that need the pull side of the round trip to echo back
    /// specific server rows.
    Map<String, dynamic> pullResponseWithNotes(
      List<Map<String, dynamic>> notes,
    ) => {
      'notes': notes,
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
      storageValues['current_owner_id'] = ownerId;

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
      DateTime? date,
      bool isDeleted = false,
      String? ownerKey = ownerId,
    }) async {
      await database
          .into(database.notes)
          .insert(
            Note(
              id: id,
              title: 'Title $id',
              content: 'Content $id',
              date: date ?? DateTime(2026, 1, 1),
              updatedAt: updatedAt,
              isDeleted: isDeleted,
              pendingSync: pendingSync,
              ownerKey: ownerKey,
            ),
          );
    }

    Future<void> insertFolder(
      String id, {
      required bool pendingSync,
      DateTime? updatedAt,
      String? ownerKey = ownerId,
    }) async {
      await database
          .into(database.folders)
          .insert(
            Folder(
              id: id,
              name: 'Folder $id',
              color: '#E8B731',
              isShared: false,
              createdAt: DateTime(2026, 1, 1),
              updatedAt: updatedAt,
              isDeleted: false,
              pendingSync: pendingSync,
              ownerKey: ownerKey,
            ),
          );
    }

    Future<Note> readNote(String id) => (database.select(
      database.notes,
    )..where((t) => t.id.equals(id))).getSingle();

    Future<Folder> readFolder(String id) => (database.select(
      database.folders,
    )..where((t) => t.id.equals(id))).getSingle();

    test('only pendingSync rows are pushed; pushed rows clear the flag and '
        'clean rows are left untouched', () async {
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
    });

    test('a row re-edited mid-round-trip (updatedAt changed after being read) '
        'keeps its pendingSync flag set', () async {
      await insertNote(
        'racy-note',
        pendingSync: true,
        updatedAt: DateTime(2026, 3, 1),
      );

      when(() => apiService.post(any(), any())).thenAnswer((_) async {
        // Simulate the note being edited again while the push is in
        // flight: bump updatedAt and pendingSync after the server already
        // has the payload, but before the client clears the flag.
        await (database.update(
          database.notes,
        )..where((t) => t.id.equals('racy-note'))).write(
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
    });

    test('unreachable server (checkHealth false) returns offline and never '
        'posts', () async {
      when(() => apiService.checkHealth()).thenAnswer((_) async => false);

      final service = buildService();
      final result = await service.sync();

      expect(result.status, SyncStatus.offline);
      verifyNever(() => apiService.post(any(), any()));
    });

    test('no current_owner_id (guest) returns idle and never posts', () async {
      storageValues.remove('current_owner_id');

      final service = buildService();
      final result = await service.sync();

      expect(result.status, SyncStatus.idle);
      verifyNever(() => apiService.post(any(), any()));
    });

    test(
      'a push that fails once then succeeds retries and reports success',
      () async {
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
      },
    );

    test('a push that always fails gives up after exhausting the retry '
        'backoff and reports error', () async {
      when(
        () => apiService.post(any(), any()),
      ).thenThrow(ApiException(500, 'permanent failure'));

      final service = buildService(
        retryBackoff: const [Duration.zero, Duration.zero],
      );
      final result = await service.sync();

      expect(result.status, SyncStatus.error);
      verify(() => apiService.post(any(), any())).called(3);
    });

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

    group('C4/C5: safe server apply (LWW guard, null-date fallback)', () {
      test('a local note edited mid-round-trip is not clobbered by a stale '
          'server echo of its pre-edit copy', () async {
        final t1 = DateTime(2026, 1, 1);
        final t2 = t1.add(const Duration(minutes: 5));
        // Locally dirty and newer than the copy the server is about to
        // echo back.
        await insertNote('n1', pendingSync: true, updatedAt: t2, date: t1);

        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => pullResponseWithNotes([
            {
              'id': 'n1',
              'title': 'Stale Server Title',
              'content': 'Stale server content',
              'date': t1.toIso8601String(),
              'audio_path': null,
              'folder_id': null,
              'is_deleted': false,
              'updated_at': t1.toIso8601String(),
            },
          ]),
        );

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.success);
        final row = await readNote('n1');
        expect(row.title, 'Title n1');
      });

      test('a new server note with a null date applies using updated_at as '
          'fallback instead of crashing', () async {
        final t = DateTime(2026, 5, 1, 10, 30);

        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => pullResponseWithNotes([
            {
              'id': 'srv',
              'title': 'Server Note',
              'content': 'Server content',
              'date': null,
              'audio_path': null,
              'folder_id': null,
              'is_deleted': false,
              'updated_at': t.toIso8601String(),
            },
          ]),
        );

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.success);
        final row = await readNote('srv');
        expect(row.date, t);
      });

      test('a note deleted locally after a prior push is not resurrected by '
          'a stale live echo from the server', () async {
        final t1 = DateTime(2026, 6, 1);
        final t2 = t1.add(const Duration(minutes: 5));
        // Deleted locally (and dirty from that delete) after t1, which is
        // the copy the server still has and echoes back as live.
        await insertNote(
          'n1',
          pendingSync: true,
          updatedAt: t2,
          date: t1,
          isDeleted: true,
        );

        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => pullResponseWithNotes([
            {
              'id': 'n1',
              'title': 'Title n1',
              'content': 'Content n1',
              'date': t1.toIso8601String(),
              'audio_path': null,
              'folder_id': null,
              'is_deleted': false,
              'updated_at': t1.toIso8601String(),
            },
          ]),
        );

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.success);
        final row = await readNote('n1');
        expect(row.isDeleted, isTrue);
      });
    });

    group('owner-scoped sync (cross-account leak fix)', () {
      test(
        'a pendingSync row owned by a different account is never pushed',
        () async {
          await insertNote('mine', pendingSync: true); // ownerKey: ownerId
          await insertNote('not-mine', pendingSync: true, ownerKey: 'other');
          await insertFolder('mine-folder', pendingSync: true);
          await insertFolder(
            'not-mine-folder',
            pendingSync: true,
            ownerKey: 'other',
          );

          late Map<String, dynamic> pushedPayload;
          when(() => apiService.post(any(), any())).thenAnswer((
            invocation,
          ) async {
            pushedPayload =
                invocation.positionalArguments[1] as Map<String, dynamic>;
            return emptyPullResponse();
          });

          final service = buildService();
          final result = await service.sync();

          expect(result.status, SyncStatus.success);
          final noteIds = (pushedPayload['notes'] as List)
              .map((n) => (n as Map)['id'])
              .toList();
          final folderIds = (pushedPayload['folders'] as List)
              .map((f) => (f as Map)['id'])
              .toList();
          expect(noteIds, ['mine']);
          expect(folderIds, ['mine-folder']);
        },
      );

      test('a note and folder pulled from the server are stamped with the '
          'current owner id', () async {
        final t = DateTime(2026, 4, 1);
        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => {
            'notes': [
              {
                'id': 'srv-note',
                'title': 'Server Note',
                'content': 'Server content',
                'date': t.toIso8601String(),
                'audio_path': null,
                'folder_id': null,
                'is_deleted': false,
                'updated_at': t.toIso8601String(),
              },
            ],
            'folders': [
              {
                'id': 'srv-folder',
                'name': 'Server Folder',
                'color': '#123456',
                'is_deleted': false,
                'updated_at': t.toIso8601String(),
              },
            ],
            'artifacts': [],
            'artifact_comments': [],
            'sync_timestamp': DateTime.now().toIso8601String(),
          },
        );

        final service = buildService();
        final result = await service.sync();

        expect(result.status, SyncStatus.success);
        expect((await readNote('srv-note')).ownerKey, ownerId);
        expect((await readFolder('srv-folder')).ownerKey, ownerId);
      });
    });

    /// The whole point of the revision guard: when the server refuses a note
    /// because someone else wrote to it first, the local edit must survive as
    /// its own row instead of being overwritten by the server's version.
    group('conflict handling', () {
      test('sends the baseRevision each row was edited from', () async {
        await insertNote('n1', pendingSync: true);
        await (database.update(database.notes)..where((t) => t.id.equals('n1')))
            .write(const NotesCompanion(baseRevision: Value(4)));

        Map<String, dynamic>? sent;
        when(() => apiService.post(any(), any())).thenAnswer((
          invocation,
        ) async {
          sent = invocation.positionalArguments[1] as Map<String, dynamic>;
          return emptyPullResponse();
        });

        await buildService().sync();

        expect((sent!['notes'] as List).single['base_revision'], 4);
      });

      test('stores the revision the server assigned', () async {
        await insertNote('n1', pendingSync: true);
        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => {
            ...emptyPullResponse(),
            'notes': [
              {
                'id': 'n1',
                'title': 'Server copy',
                'content': '',
                'date': DateTime(2026, 8, 2).toIso8601String(),
                'updated_at': DateTime(2026, 8, 3).toIso8601String(),
                'is_deleted': false,
                'revision': 7,
              },
            ],
          },
        );

        await buildService().sync();

        final saved = await (database.select(
          database.notes,
        )..where((t) => t.id.equals('n1'))).getSingle();
        expect(saved.baseRevision, 7);
      });

      test('carries authorship in both directions', () async {
        await insertNote('n1', pendingSync: true);
        await (database.update(database.notes)..where((t) => t.id.equals('n1')))
            .write(const NotesCompanion(authorId: Value(ownerId)));

        Map<String, dynamic>? sent;
        when(() => apiService.post(any(), any())).thenAnswer((
          invocation,
        ) async {
          sent = invocation.positionalArguments[1] as Map<String, dynamic>;
          return {
            ...emptyPullResponse(),
            'notes': [
              {
                'id': 'n-theirs',
                'title': 'Слой 3',
                'content': '',
                'date': DateTime(2026, 8, 2).toIso8601String(),
                'updated_at': DateTime(2026, 8, 3).toIso8601String(),
                'is_deleted': false,
                'author_id': 'maria',
              },
            ],
          };
        });

        await buildService().sync();

        expect((sent!['notes'] as List).single['author_id'], ownerId);

        final theirs = await (database.select(
          database.notes,
        )..where((t) => t.id.equals('n-theirs'))).getSingle();
        // Authored by a colleague, but stored in THIS account's replica.
        // Conflating the two is what would let her rows show up under a
        // different account on the same phone.
        expect(theirs.authorId, 'maria');
        expect(theirs.ownerKey, ownerId);
      });

      test(
        "a colleague's note stays invisible to a different local account",
        () async {
          when(() => apiService.post(any(), any())).thenAnswer(
            (_) async => {
              ...emptyPullResponse(),
              'notes': [
                {
                  'id': 'n-theirs',
                  'title': 'Слой 3',
                  'content': '',
                  'date': DateTime(2026, 8, 2).toIso8601String(),
                  'updated_at': DateTime(2026, 8, 3).toIso8601String(),
                  'is_deleted': false,
                  'author_id': 'maria',
                },
              ],
            },
          );

          await buildService().sync();

          // A second account on the same device must not see it. This is the
          // leak test: sharing widened what arrives locally, and ownerKey is the
          // only thing keeping accounts apart on one phone.
          final otherAccount = NotesRepository(
            database,
            ownerHolder: CurrentOwnerHolder('someone-else'),
          );
          final visible = await otherAccount.watchAllNotes().first;
          expect(visible.map((n) => n.id), isNot(contains('n-theirs')));
        },
      );

      test('forks a refused note and keeps its dirty flag', () async {
        await insertNote('n1', pendingSync: true);
        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => {
            ...emptyPullResponse(),
            'conflicted_note_ids': ['n1'],
          },
        );

        await buildService().sync();

        final rows = await database.select(database.notes).get();
        expect(rows, hasLength(2), reason: 'the original plus the fork');

        final fork = rows.firstWhere((r) => r.id != 'n1');
        // The fork carries the local edit and still has to reach the server.
        expect(fork.pendingSync, isTrue);
        // It has never been to the server, so it uploads as a create rather
        // than racing again against the revision it just lost to.
        expect(fork.baseRevision, isNull);

        // The refused row keeps its dirty flag: the server never accepted it,
        // and clearing it would drop the user's edit silently.
        final original = rows.firstWhere((r) => r.id == 'n1');
        expect(original.pendingSync, isTrue);
      });

      test('a note the server accepted still gets its flag cleared', () async {
        await insertNote('n1', pendingSync: true);
        await insertNote('n2', pendingSync: true);
        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => {
            ...emptyPullResponse(),
            'conflicted_note_ids': ['n1'],
          },
        );

        await buildService().sync();

        final accepted = await (database.select(
          database.notes,
        )..where((t) => t.id.equals('n2'))).getSingle();
        expect(
          accepted.pendingSync,
          isFalse,
          reason: 'only the refused row keeps its flag',
        );
      });
    });

    /// Losing access to a dig site must not strand what you wrote in it.
    /// Server-side the rows survive; this is what the person actually sees.
    group('losing access to a shared folder', () {
      test(
        'detaches notes from a folder that is no longer reachable',
        () async {
          await insertFolder('f1', pendingSync: false);
          await insertNote('n1', pendingSync: false);
          await (database.update(database.notes)
                ..where((t) => t.id.equals('n1')))
              .write(const NotesCompanion(folderId: Value('f1')));

          // Access was revoked while she was in the field: f1 is simply absent
          // from the set the server now reports.
          when(() => apiService.post(any(), any())).thenAnswer(
            (_) async => {
              ...emptyPullResponse(),
              'accessible_folder_ids': <String>[],
            },
          );

          await buildService().sync();

          final note = await (database.select(
            database.notes,
          )..where((t) => t.id.equals('n1'))).getSingle();
          // Detached, never deleted: an admin action by someone else must not
          // destroy her writing.
          expect(note.folderId, isNull);
          expect(note.isDeleted, isFalse);
          expect(note.title, isNotEmpty);
        },
      );

      test('leaves notes alone when the folder is still reachable', () async {
        await insertFolder('f1', pendingSync: false);
        await insertNote('n1', pendingSync: false);
        await (database.update(database.notes)..where((t) => t.id.equals('n1')))
            .write(const NotesCompanion(folderId: Value('f1')));

        when(() => apiService.post(any(), any())).thenAnswer(
          (_) async => {
            ...emptyPullResponse(),
            'accessible_folder_ids': ['f1'],
          },
        );

        await buildService().sync();

        final note = await (database.select(
          database.notes,
        )..where((t) => t.id.equals('n1'))).getSingle();
        expect(note.folderId, 'f1');
      });

      test('does not detach anything when the sync failed', () async {
        await insertFolder('f1', pendingSync: false);
        await insertNote('n1', pendingSync: false);
        await (database.update(database.notes)..where((t) => t.id.equals('n1')))
            .write(const NotesCompanion(folderId: Value('f1')));

        // A failed sync reports no folders either. Detaching on that would
        // dismantle a working setup every time signal dropped -- far worse
        // than the bug being fixed.
        when(
          () => apiService.post(any(), any()),
        ).thenThrow(Exception('network down'));

        await buildService().sync();

        final note = await (database.select(
          database.notes,
        )..where((t) => t.id.equals('n1'))).getSingle();
        expect(note.folderId, 'f1');
      });
    });
  });

  group('ApiService.checkHealth', () {
    test('probes the root /health path (not under /api/v1) and returns true '
        'on HTTP 200', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response('', 200);
      });

      final api = ApiService(authService: AuthService(), client: client);
      addTearDown(api.dispose);

      final healthy = await api.checkHealth();

      expect(healthy, isTrue);
      expect(requestedUri, isNotNull);
      expect(requestedUri!.path, '/health');
      expect(requestedUri!.toString(), isNot(contains('/api/v1')));
    });

    test('returns false on a non-200 response', () async {
      final api = ApiService(
        authService: AuthService(),
        client: MockClient((request) async => http.Response('', 503)),
      );
      addTearDown(api.dispose);

      expect(await api.checkHealth(), isFalse);
    });

    test('returns false instead of throwing on a network error', () async {
      final api = ApiService(
        authService: AuthService(),
        client: MockClient((request) async {
          throw const SocketException('no route to host');
        }),
      );
      addTearDown(api.dispose);

      expect(await api.checkHealth(), isFalse);
    });
  });
}
