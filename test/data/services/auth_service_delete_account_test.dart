import 'package:archset_r2/data/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_secure_storage.dart';

/// Mirrors auth_service_logout_test.dart: deleteAccount() must clear the
/// namespaced session exactly like logout() does (the tokens are dead on
/// the server either way), but -- unlike logout() -- it must NOT clear
/// anything if the server call fails, since the account (and its session)
/// still exists in that case.
const _baseUrl = 'http://127.0.0.1:8000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> storageValues;

  setUp(() {
    storageValues = installFakeSecureStorage();
  });

  test('deleteAccount sends a DELETE with the bearer token and clears the '
      'namespaced session on success', () async {
    final slug = AuthStorageKeys.originSlug(_baseUrl);
    http.Request? sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response('', 204);
    });
    final service = AuthService(
      storage: const FlutterSecureStorage(),
      baseUrl: _baseUrl,
      client: client,
    );
    addTearDown(service.dispose);

    storageValues[AuthStorageKeys.accessToken(slug)] = 'access-token';
    storageValues[AuthStorageKeys.refreshToken(slug)] = 'refresh-token';
    storageValues[AuthStorageKeys.userId(slug)] = 'user-1';
    storageValues[AuthStorageKeys.userEmail(slug)] = 'a@example.com';
    storageValues[AuthStorageKeys.userCreatedAt(slug)] =
        '2026-01-01T00:00:00.000Z';
    storageValues[AuthStorageKeys.currentOwnerId] = 'user-1';

    await service.deleteAccount();

    expect(sentRequest?.method, 'DELETE');
    expect(sentRequest?.url.path, endsWith('/auth/me'));
    expect(sentRequest?.headers['Authorization'], 'Bearer access-token');

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
  });

  test('deleteAccount throws and leaves the session untouched when the server '
      'rejects the request', () async {
    final slug = AuthStorageKeys.originSlug(_baseUrl);
    final client = MockClient(
      (request) async =>
          http.Response('{"detail": "Could not validate credentials"}', 401),
    );
    final service = AuthService(
      storage: const FlutterSecureStorage(),
      baseUrl: _baseUrl,
      client: client,
    );
    addTearDown(service.dispose);

    storageValues[AuthStorageKeys.accessToken(slug)] = 'access-token';

    await expectLater(service.deleteAccount(), throwsA(isA<Exception>()));

    expect(
      storageValues.containsKey(AuthStorageKeys.accessToken(slug)),
      isTrue,
    );
  });
}
