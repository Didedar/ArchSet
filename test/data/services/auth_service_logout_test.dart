import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_secure_storage.dart';

/// B4: in the offline-first model, the on-device diary belongs to the
/// device/guest until it's claimed by a sign-in, so `logout()` must clear
/// only the namespaced session (+ `currentOwnerId`) and must never touch
/// local notes/folders/artifacts.
///
/// This lives in its own file, separate from `auth_service_test.dart`,
/// because it needs a REAL in-memory drift database rather than
/// `FakeAppDatabase`: the entire point of the test is that a row inserted
/// before `logout()` is still readable afterwards, which a fake/no-op
/// database can't actually prove.
const _baseUrl = 'http://127.0.0.1:8000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late Map<String, String> storageValues;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    storageValues = installFakeSecureStorage();
  });

  tearDown(() => database.close());

  test('logout clears the namespaced session and currentOwnerId but leaves the '
      'local diary untouched', () async {
    final slug = AuthStorageKeys.originSlug(_baseUrl);
    final client = MockClient((request) async => http.Response('', 204));
    final service = AuthService(
      storage: const FlutterSecureStorage(),
      baseUrl: _baseUrl,
      client: client,
    );
    addTearDown(service.dispose);

    // Seed a local note...
    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n1',
            title: 'Trench A',
            content: 'context 42',
            date: DateTime(2026, 1, 1),
          ),
        );

    // ...and a live namespaced session.
    storageValues[AuthStorageKeys.accessToken(slug)] = 'access-token';
    storageValues[AuthStorageKeys.refreshToken(slug)] = 'refresh-token';
    storageValues[AuthStorageKeys.userId(slug)] = 'user-1';
    storageValues[AuthStorageKeys.userEmail(slug)] = 'a@example.com';
    storageValues[AuthStorageKeys.userCreatedAt(slug)] =
        '2026-01-01T00:00:00.000Z';
    storageValues[AuthStorageKeys.currentOwnerId] = 'user-1';

    await service.logout();

    expect(
      storageValues.containsKey(AuthStorageKeys.accessToken(slug)),
      isFalse,
    );
    expect(
      storageValues.containsKey(AuthStorageKeys.refreshToken(slug)),
      isFalse,
    );
    expect(storageValues.containsKey(AuthStorageKeys.userId(slug)), isFalse);
    expect(storageValues.containsKey(AuthStorageKeys.userEmail(slug)), isFalse);
    expect(
      storageValues.containsKey(AuthStorageKeys.userCreatedAt(slug)),
      isFalse,
    );
    expect(storageValues.containsKey(AuthStorageKeys.currentOwnerId), isFalse);

    final notes = await database.select(database.notes).get();
    expect(notes.map((n) => n.id), ['n1']);
  });
}
