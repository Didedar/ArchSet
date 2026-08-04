import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:archset_r2/data/services/auth_service.dart';

import '../../support/fake_secure_storage.dart';

/// Which stored session belongs to which backend.
///
/// Tokens are namespaced by origin so a JWT minted by production is never read
/// back as valid for a dev server -- they sign with different secrets and hold
/// different user tables. But one dev backend answers at several addresses at
/// once: the USB tunnel (127.0.0.1), the machine's Wi-Fi address, the
/// emulator's 10.0.2.2. Those are the same server and the same accounts.
///
/// Namespacing them apart signed the user out whenever the route changed --
/// and a signed-out session hides every account-owned diary, so the app looks
/// empty and refuses to save while the rows sit intact on disk. That is the
/// failure this pins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('origin namespacing', () {
    test('every route to the dev backend shares one namespace', () {
      final slugs = {
        for (final url in [
          'http://127.0.0.1:8000', // USB tunnel
          'http://10.240.102.61:8000', // this machine over Wi-Fi
          'http://10.0.2.2:8000', // the emulator's alias for its host
          'http://192.168.1.42:8000', // a home network
          'http://localhost:8000',
        ])
          AuthStorageKeys.originSlug(url),
      };

      expect(slugs, hasLength(1), reason: 'same backend, same account space');
    });

    test('production keeps a namespace of its own', () {
      expect(
        AuthStorageKeys.originSlug(
          'https://archset-backend-production.up.railway.app',
        ),
        isNot(AuthStorageKeys.originSlug('http://127.0.0.1:8000')),
      );
    });

    test('two different public backends stay apart', () {
      expect(
        AuthStorageKeys.originSlug('https://a.example.com'),
        isNot(AuthStorageKeys.originSlug('https://b.example.com')),
      );
    });
  });

  group('adopting a session left by an older build', () {
    late Map<String, String> storage;

    setUp(() {
      storage = installFakeSecureStorage();
    });

    /// Signed in against the dev backend, currently reached over the tunnel.
    AuthService devService() => AuthService(
      storage: const FlutterSecureStorage(),
      baseUrl: 'http://127.0.0.1:8000',
      client: MockClient((_) async => throw const SocketException('offline')),
    );

    void givenSessionStoredAs(String slug) {
      storage['access_token_$slug'] = 'access';
      storage['refresh_token_$slug'] = 'refresh';
      storage['user_id_$slug'] = 'ivan';
      storage['user_email_$slug'] = 'ivan@example.com';
      storage['user_created_at_$slug'] = '2026-01-01T00:00:00.000Z';
    }

    test('a session namespaced by address is still found', () async {
      givenSessionStoredAs('127_0_0_1_8000');
      final service = devService();
      addTearDown(service.dispose);

      expect(await service.getAccessToken(), 'access');
      expect(await service.getRefreshToken(), 'refresh');
    });

    test('the whole identity moves across, not just the token', () async {
      givenSessionStoredAs('127_0_0_1_8000');
      final service = devService();
      addTearDown(service.dispose);

      await service.getAccessToken();

      const slug = AuthStorageKeys.devSlug;
      expect(storage[AuthStorageKeys.userId(slug)], 'ivan');
      expect(storage[AuthStorageKeys.userEmail(slug)], 'ivan@example.com');
      expect(storage[AuthStorageKeys.userCreatedAt(slug)], isNotNull);
      expect(
        storage['access_token_127_0_0_1_8000'],
        isNull,
        reason: 'moved, not copied -- two namespaces would drift apart',
      );
    });

    test('signed in over Wi-Fi yesterday, over the tunnel today', () async {
      // DHCP hands the machine a new address; the session must not care.
      givenSessionStoredAs('10_240_102_57_8000');
      final service = devService();
      addTearDown(service.dispose);

      expect(await service.getAccessToken(), 'access');
    });

    test('a current session is never overwritten by an older one', () async {
      givenSessionStoredAs('127_0_0_1_8000');
      storage[AuthStorageKeys.accessToken(AuthStorageKeys.devSlug)] = 'current';
      final service = devService();
      addTearDown(service.dispose);

      expect(await service.getAccessToken(), 'current');
    });

    test('a production session is not adopted as a dev one', () async {
      // The whole point of namespacing: this token means nothing here.
      givenSessionStoredAs('archset_backend_production_up_railway_app_443');
      final service = devService();
      addTearDown(service.dispose);

      expect(await service.getAccessToken(), isNull);
    });

    test('un-namespaced keys from a much older build are ignored', () async {
      // Real installs carry both: `access_token` from before namespacing
      // existed, alongside `access_token_127_0_0_1_8000`. The bare one must
      // not be mistaken for a slug, or it would be adopted as a session.
      storage['access_token'] = 'ancient';
      storage['user_id'] = 'someone-else';
      givenSessionStoredAs('127_0_0_1_8000');
      final service = devService();
      addTearDown(service.dispose);

      expect(await service.getAccessToken(), 'access');
      expect(storage['access_token'], 'ancient', reason: 'left untouched');
    });

    test('no stored session at all stays a guest', () async {
      final service = devService();
      addTearDown(service.dispose);

      expect(await service.getAccessToken(), isNull);
    });
  });
}
