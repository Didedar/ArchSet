import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:archset_r2/data/services/auth_service.dart';

import '../../support/fake_app_database.dart';
import '../../support/fake_secure_storage.dart';

/// B2 namespaces token storage by backend origin: a JWT minted by production
/// must never be read back as if it came from localhost (and vice versa),
/// since the two backends sign with different secrets and have different
/// user databases. These tests exercise that isolation directly through the
/// public API, plus the new `currentOwnerId` bookkeeping and the
/// session-expired broadcast that a later task (B6) wires into SessionCubit.
const _prodBaseUrl = 'https://archset-backend-production.up.railway.app';
const _localBaseUrl = 'http://127.0.0.1:8000';

/// A MockClient that answers `/auth/login`, `/auth/register`, `/auth/me`,
/// and `/auth/refresh` for a single fake account, so each test only has to
/// say who is signing in.
MockClient _clientFor({
  required String userId,
  required String userEmail,
  String accessToken = 'access-token',
  String refreshToken = 'refresh-token',
}) {
  final tokenBody = jsonEncode({
    'access_token': accessToken,
    'refresh_token': refreshToken,
  });
  final userBody = jsonEncode({
    'id': userId,
    'email': userEmail,
    'created_at': '2026-01-01T00:00:00.000Z',
  });

  return MockClient((request) async {
    const headers = {'content-type': 'application/json'};
    final path = request.url.path;
    if (path.endsWith('/auth/login') || path.endsWith('/auth/refresh')) {
      return http.Response(tokenBody, 200, headers: headers);
    }
    if (path.endsWith('/auth/me')) {
      return http.Response(userBody, 200, headers: headers);
    }
    if (path.endsWith('/auth/register')) {
      return http.Response(userBody, 201, headers: headers);
    }
    return http.Response('not found', 404);
  });
}

AuthService _service({required String baseUrl, required MockClient client}) {
  return AuthService(
    database: FakeAppDatabase(),
    storage: const FlutterSecureStorage(),
    baseUrl: baseUrl,
    client: client,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> storageValues;

  setUp(() {
    storageValues = installFakeSecureStorage();
  });

  group('AuthStorageKeys.originSlug', () {
    test('differs between the production and localhost origins', () {
      final prodSlug = AuthStorageKeys.originSlug(_prodBaseUrl);
      final localSlug = AuthStorageKeys.originSlug(_localBaseUrl);

      expect(prodSlug, isNot(equals(localSlug)));
    });

    test('produces the documented slug for 127.0.0.1:8000', () {
      expect(AuthStorageKeys.originSlug(_localBaseUrl), '127_0_0_1_8000');
    });
  });

  group('login', () {
    test(
      'stores tokens under the origin-scoped keys and sets currentOwnerId',
      () async {
        final service = _service(
          baseUrl: _prodBaseUrl,
          client: _clientFor(userId: 'user-1', userEmail: 'a@example.com'),
        );
        addTearDown(service.dispose);
        final slug = AuthStorageKeys.originSlug(_prodBaseUrl);

        final user = await service.login('a@example.com', 'password123');

        expect(user.id, 'user-1');
        expect(
          storageValues[AuthStorageKeys.accessToken(slug)],
          'access-token',
        );
        expect(
          storageValues[AuthStorageKeys.refreshToken(slug)],
          'refresh-token',
        );
        expect(storageValues[AuthStorageKeys.userId(slug)], 'user-1');
        expect(storageValues[AuthStorageKeys.userEmail(slug)], 'a@example.com');
        expect(storageValues[AuthStorageKeys.currentOwnerId], 'user-1');
      },
    );

    test('writes no bare, un-namespaced token keys', () async {
      final service = _service(
        baseUrl: _prodBaseUrl,
        client: _clientFor(userId: 'user-1', userEmail: 'a@example.com'),
      );
      addTearDown(service.dispose);

      await service.login('a@example.com', 'password123');

      expect(storageValues.containsKey('access_token'), isFalse);
      expect(storageValues.containsKey('refresh_token'), isFalse);
      expect(storageValues.containsKey('user_id'), isFalse);
      expect(storageValues.containsKey('user_email'), isFalse);
    });
  });

  group('register', () {
    test('sets currentOwnerId from the newly created account', () async {
      final service = _service(
        baseUrl: _prodBaseUrl,
        client: _clientFor(userId: 'user-2', userEmail: 'new@example.com'),
      );
      addTearDown(service.dispose);

      final user = await service.register('new@example.com', 'password123');

      expect(user.id, 'user-2');
      expect(storageValues[AuthStorageKeys.currentOwnerId], 'user-2');
    });
  });

  group('origin isolation', () {
    test('a token written under one backend origin is invisible to a service '
        'configured for a different origin, and vice versa', () async {
      final prodService = _service(
        baseUrl: _prodBaseUrl,
        client: _clientFor(
          userId: 'prod-user',
          userEmail: 'prod@example.com',
          accessToken: 'prod-access',
          refreshToken: 'prod-refresh',
        ),
      );
      addTearDown(prodService.dispose);
      final localService = _service(
        baseUrl: _localBaseUrl,
        client: _clientFor(
          userId: 'local-user',
          userEmail: 'local@example.com',
          accessToken: 'local-access',
          refreshToken: 'local-refresh',
        ),
      );
      addTearDown(localService.dispose);

      await prodService.login('prod@example.com', 'password123');

      expect(await prodService.getAccessToken(), 'prod-access');
      expect(await localService.getAccessToken(), isNull);

      await localService.login('local@example.com', 'password123');

      expect(await localService.getAccessToken(), 'local-access');
      expect(await prodService.getAccessToken(), 'prod-access');
    });
  });

  group('onSessionExpired', () {
    test('notifySessionExpired emits an event on the stream', () async {
      final service = _service(
        baseUrl: _prodBaseUrl,
        client: _clientFor(userId: 'x', userEmail: 'x@example.com'),
      );
      addTearDown(service.dispose);

      final future = service.onSessionExpired.first;
      service.notifySessionExpired();

      await expectLater(future, completes);
    });
  });

  group('loadStoredUser (fail-closed)', () {
    final slug = AuthStorageKeys.originSlug(_localBaseUrl);

    test('no stored token returns null and makes no HTTP call', () async {
      final client = MockClient((request) async {
        fail('unexpected HTTP call: ${request.method} ${request.url}');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      final user = await service.loadStoredUser();

      expect(user, isNull);
    });

    test('a valid token returns the server user with its real createdAt and '
        'sets currentOwnerId', () async {
      storageValues[AuthStorageKeys.accessToken(slug)] = 'valid-token';
      // A stale cached identity from a previous run; the fresh /auth/me
      // response must win, not this cached copy.
      storageValues[AuthStorageKeys.userId(slug)] = 'stale-cached-id';
      storageValues[AuthStorageKeys.userEmail(slug)] =
          'stale-cached@example.com';

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'id': 'user-9',
              'email': 'nine@example.com',
              'created_at': '2020-05-06T07:08:09.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('unexpected HTTP call: ${request.method} ${request.url}');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      final user = await service.loadStoredUser();

      expect(user, isNotNull);
      expect(user!.id, 'user-9');
      expect(user.email, 'nine@example.com');
      expect(user.createdAt, DateTime.parse('2020-05-06T07:08:09.000Z'));
      expect(storageValues[AuthStorageKeys.currentOwnerId], 'user-9');
    });

    test('401 followed by a successful refresh returns the refreshed user and '
        'stores the new access token', () async {
      storageValues[AuthStorageKeys.accessToken(slug)] = 'stale-token';
      storageValues[AuthStorageKeys.refreshToken(slug)] = 'refresh-token';
      storageValues[AuthStorageKeys.userId(slug)] = 'old-id';
      storageValues[AuthStorageKeys.userEmail(slug)] = 'old@example.com';

      var meCalls = 0;
      final client = MockClient((request) async {
        const headers = {'content-type': 'application/json'};
        final path = request.url.path;
        if (path.endsWith('/auth/me')) {
          meCalls++;
          if (meCalls == 1) {
            return http.Response(
              jsonEncode({'detail': 'Unauthorized'}),
              401,
              headers: headers,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'user-refreshed',
              'email': 'refreshed@example.com',
              'created_at': '2021-02-03T04:05:06.000Z',
            }),
            200,
            headers: headers,
          );
        }
        if (path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            }),
            200,
            headers: headers,
          );
        }
        fail('unexpected HTTP call: ${request.method} ${request.url}');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      final user = await service.loadStoredUser();

      expect(user, isNotNull);
      expect(user!.id, 'user-refreshed');
      expect(meCalls, 2);
      expect(storageValues[AuthStorageKeys.accessToken(slug)], 'new-access');
    });

    test('401 with a failed refresh clears the namespaced session and returns '
        'null', () async {
      storageValues[AuthStorageKeys.accessToken(slug)] = 'dead-token';
      storageValues[AuthStorageKeys.refreshToken(slug)] = 'dead-refresh';
      storageValues[AuthStorageKeys.userId(slug)] = 'old-id';
      storageValues[AuthStorageKeys.userEmail(slug)] = 'old@example.com';
      storageValues[AuthStorageKeys.currentOwnerId] = 'old-id';

      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/me') || path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({'detail': 'Unauthorized'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        fail('unexpected HTTP call: ${request.method} ${request.url}');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      final user = await service.loadStoredUser();

      expect(user, isNull);
      expect(
        storageValues.containsKey(AuthStorageKeys.accessToken(slug)),
        isFalse,
      );
      expect(
        storageValues.containsKey(AuthStorageKeys.refreshToken(slug)),
        isFalse,
      );
      expect(storageValues.containsKey(AuthStorageKeys.userId(slug)), isFalse);
      expect(
        storageValues.containsKey(AuthStorageKeys.userEmail(slug)),
        isFalse,
      );
      expect(
        storageValues.containsKey(AuthStorageKeys.currentOwnerId),
        isFalse,
      );
    });

    test('a network error (offline) returns null but preserves the stored '
        'access token', () async {
      storageValues[AuthStorageKeys.accessToken(slug)] = 'still-good-token';
      storageValues[AuthStorageKeys.userId(slug)] = 'old-id';
      storageValues[AuthStorageKeys.userEmail(slug)] = 'old@example.com';

      final client = MockClient((request) async {
        throw const SocketException('offline');
      });
      final service = _service(baseUrl: _localBaseUrl, client: client);
      addTearDown(service.dispose);

      final user = await service.loadStoredUser();

      expect(user, isNull);
      expect(
        storageValues[AuthStorageKeys.accessToken(slug)],
        'still-good-token',
      );
    });
  });

  group('cached identity', () {
    test('login persists createdAt alongside id and email', () async {
      final slug = AuthStorageKeys.originSlug(_prodBaseUrl);
      final client = _clientFor(userId: 'u1', userEmail: 'u1@example.com');
      final service = _service(baseUrl: _prodBaseUrl, client: client);
      addTearDown(service.dispose);

      await service.login('u1@example.com', 'password');

      expect(
        storageValues[AuthStorageKeys.userCreatedAt(slug)],
        '2026-01-01T00:00:00.000Z',
      );
    });
  });
}
