import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:archset_r2/data/current_owner_holder.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';

import '../../support/fake_secure_storage.dart';

/// Regression for the offline-launch bug: `loadStoredUser()` returned null
/// when the backend was unreachable, `SessionCubit` read that as a guest,
/// `CurrentOwnerHolder` went null, and `NotesRepository` then filtered out
/// every row owned by the account. The user saw an empty diary with their
/// data intact on disk.
///
/// This exercises the whole chain rather than any single layer, because every
/// layer in it was individually behaving as designed -- the defect only
/// existed in how they composed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localBaseUrl = 'http://127.0.0.1:8000';
  final slug = AuthStorageKeys.originSlug(localBaseUrl);

  late Map<String, String> storageValues;
  late AppDatabase database;

  setUp(() {
    storageValues = installFakeSecureStorage();
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  /// A backend that is simply not there, the way it is not there in a trench.
  AuthService offlineService() => AuthService(
    database: database,
    storage: const FlutterSecureStorage(),
    baseUrl: localBaseUrl,
    client: MockClient((request) async {
      throw const SocketException('offline');
    }),
  );

  void givenSignedInSession() {
    storageValues[AuthStorageKeys.accessToken(slug)] = 'token';
    storageValues[AuthStorageKeys.userId(slug)] = 'ivan';
    storageValues[AuthStorageKeys.userEmail(slug)] = 'ivan@example.com';
    storageValues[AuthStorageKeys.userCreatedAt(slug)] =
        '2026-01-01T00:00:00.000Z';
  }

  test(
    'an offline launch keeps the account session instead of becoming a guest',
    () async {
      givenSignedInSession();
      final service = offlineService();
      addTearDown(service.dispose);
      final holder = CurrentOwnerHolder();
      final cubit = SessionCubit(repository: service, ownerHolder: holder);
      addTearDown(cubit.close);

      await cubit.bootstrap();

      expect(cubit.state, isA<SessionAuthenticated>());
      expect((cubit.state as SessionAuthenticated).user.id, 'ivan');
      expect(holder.value, 'ivan');
    },
  );

  test('an offline launch still shows the notes the account owns', () async {
    givenSignedInSession();
    final service = offlineService();
    addTearDown(service.dispose);
    final holder = CurrentOwnerHolder();
    final repository = NotesRepository(database, ownerHolder: holder);
    final cubit = SessionCubit(repository: service, ownerHolder: holder);
    addTearDown(cubit.close);

    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n1',
            title: 'Раскоп 3, слой 2',
            content: '',
            date: DateTime(2026, 8, 2),
            ownerKey: const Value('ivan'),
          ),
        );

    await cubit.bootstrap();

    final notes = await repository.watchAllNotes().first;
    expect(notes.map((n) => n.id), contains('n1'));
  });

  test(
    'a genuine guest (no stored identity) still gets a guest session',
    () async {
      // No storage keys set at all.
      final service = offlineService();
      addTearDown(service.dispose);
      final holder = CurrentOwnerHolder();
      final cubit = SessionCubit(repository: service, ownerHolder: holder);
      addTearDown(cubit.close);

      await cubit.bootstrap();

      expect(cubit.state, isA<SessionGuest>());
      expect(holder.value, isNull);
    },
  );

  /// Spec requirement 6. A refresh token can expire while the user is in the
  /// field for weeks; the forced logout that follows must clear the session
  /// and nothing else. Asserted rather than inferred from the method name.
  test('a forced logout (rejected token, failed refresh) clears the session '
      'but leaves unsynced notes on the device', () async {
    givenSignedInSession();
    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n-dirty',
            title: 'Слой 3, не отправлено',
            content: '',
            date: DateTime(2026, 8, 2),
            ownerKey: const Value('ivan'),
            pendingSync: const Value(true),
          ),
        );

    // Server is reachable and says the token is dead; the refresh dies too.
    final service = AuthService(
      database: database,
      storage: const FlutterSecureStorage(),
      baseUrl: localBaseUrl,
      client: MockClient((request) async => http.Response('{}', 401)),
    );
    addTearDown(service.dispose);

    expect(await service.loadStoredUser(), isNull);
    expect(storageValues[AuthStorageKeys.accessToken(slug)], isNull);

    final rows = await database.select(database.notes).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'n-dirty');
    expect(rows.single.pendingSync, isTrue);
  });
}
