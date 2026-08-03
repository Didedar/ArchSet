import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/auth_service.dart';

import '../../support/fake_secure_storage.dart';

/// B6 funnels a 401 that survives a failed token refresh through a single
/// choke point: `AuthService.notifySessionExpired()`, which SessionCubit
/// (B5) already subscribes to in order to route the app off the authed
/// surface and back to Welcome. These tests exercise that funnel through
/// `ApiService`'s public verbs against a real `AuthService` (backed by a
/// fake secure storage), so the refresh call itself is genuine, not mocked
/// away.
const _baseUrl = 'http://127.0.0.1:8000';

Map<String, dynamic> _unauthorizedBody() => {'detail': 'Unauthorized'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> storageValues;
  late String slug;

  setUp(() {
    storageValues = installFakeSecureStorage();
    slug = AuthStorageKeys.originSlug(_baseUrl);
    // Seed a namespaced access+refresh token so a 401 from the API call
    // below actually reaches AuthService.refreshAccessToken() (which
    // short-circuits to false without an HTTP call when no refresh token is
    // stored) instead of trivially failing before hitting the network.
    storageValues[AuthStorageKeys.accessToken(slug)] = 'stale-access';
    storageValues[AuthStorageKeys.refreshToken(slug)] = 'stale-refresh';
  });

  AuthService authService(MockClient refreshClient) {
    return AuthService(
      storage: const FlutterSecureStorage(),
      baseUrl: _baseUrl,
      client: refreshClient,
    );
  }

  MockClient unauthorizedClient() {
    return MockClient(
      (request) async => http.Response(
        jsonEncode(_unauthorizedBody()),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  Matcher isUnauthorizedApiException() =>
      isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401);

  group('unrecoverable 401 -> session-lost signal', () {
    test('401 whose refresh also fails rethrows the 401 and fires '
        'onSessionExpired exactly once', () async {
      final auth = authService(unauthorizedClient());
      addTearDown(auth.dispose);
      var expiredCount = 0;
      final sub = auth.onSessionExpired.listen((_) => expiredCount++);
      addTearDown(sub.cancel);

      final api = ApiService(authService: auth, client: unauthorizedClient());
      addTearDown(api.dispose);

      await expectLater(
        api.get('/notes'),
        throwsA(isUnauthorizedApiException()),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(expiredCount, 1);
    });

    test(
      '401 that a refresh fixes succeeds and fires onSessionExpired 0 times',
      () async {
        final auth = authService(
          MockClient(
            (request) async => http.Response(
              jsonEncode({
                'access_token': 'new-access',
                'refresh_token': 'new-refresh',
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(auth.dispose);
        var expiredCount = 0;
        final sub = auth.onSessionExpired.listen((_) => expiredCount++);
        addTearDown(sub.cancel);

        var apiCalls = 0;
        final api = ApiService(
          authService: auth,
          client: MockClient((request) async {
            apiCalls++;
            if (apiCalls == 1) {
              return http.Response(
                jsonEncode(_unauthorizedBody()),
                401,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({'notes': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(api.dispose);

        final result = await api.get('/notes');

        expect(result, {'notes': []});
        expect(apiCalls, 2);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(expiredCount, 0);
      },
    );

    test('a requireAuth:false 401 throws but never attempts a refresh or fires '
        'onSessionExpired', () async {
      final auth = authService(
        MockClient((request) async {
          fail('unexpected refresh call: ${request.method} ${request.url}');
        }),
      );
      addTearDown(auth.dispose);
      var expiredCount = 0;
      final sub = auth.onSessionExpired.listen((_) => expiredCount++);
      addTearDown(sub.cancel);

      final api = ApiService(authService: auth, client: unauthorizedClient());
      addTearDown(api.dispose);

      await expectLater(
        api.get('/public-notes', requireAuth: false),
        throwsA(isUnauthorizedApiException()),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(expiredCount, 0);
    });
  });
}
