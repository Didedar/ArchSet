import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/auth_service.dart';

import '../../support/fake_secure_storage.dart';

/// Noticing that the dev backend moved, without being restarted.
///
/// `ApiConfig.init()` runs once, before the first frame, and its answer used
/// to be frozen for the life of the process. So an app that launched while the
/// backend was down stayed pointed at the wrong host forever: starting the
/// backend afterwards could not help, because nothing ever looked again. That
/// is the whole reason "Connection refused" kept coming back after each
/// supposed fix.
///
/// The sync layer already probes `/health` before every sync, so that probe is
/// where a stale choice gets noticed and corrected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prod = 'https://archset-backend-production.up.railway.app';
  const loopback = 'http://127.0.0.1:8000';

  setUp(() {
    installFakeSecureStorage();
    ApiConfig.resetForTesting();
  });

  tearDown(ApiConfig.resetForTesting);

  /// A backend that answers only at [reachable]; everything else refuses, the
  /// way a dead tunnel refuses.
  MockClient serverAt(String? reachable) {
    return MockClient((request) async {
      final origin = '${request.url.scheme}://${request.url.authority}';
      if (reachable != null && origin == reachable) {
        return http.Response('{"status":"healthy"}', 200);
      }
      throw const SocketException('Connection refused');
    });
  }

  ApiService serviceWith(MockClient client) {
    return ApiService(
      client: client,
      authService: AuthService(
        storage: const FlutterSecureStorage(),
        baseUrl: loopback,
        client: client,
      ),
    );
  }

  test('a backend started after launch is picked up without a restart', () async {
    // Launch found nothing, so the app settled on production.
    expect(ApiConfig.baseUrl, prod);

    // The developer then starts the backend / re-plugs the cable.
    final client = serverAt(loopback);
    ApiConfig.probeClientFactory = () => client;

    expect(await serviceWith(client).checkHealth(), isTrue);
    expect(ApiConfig.baseUrl, loopback);
  });

  test('a healthy backend is not re-probed', () async {
    var probes = 0;
    final client = serverAt(prod);
    ApiConfig.probeClientFactory = () {
      probes++;
      return client;
    };

    expect(await serviceWith(client).checkHealth(), isTrue);
    expect(probes, 0, reason: 'nothing was wrong, so nothing to re-resolve');
    expect(ApiConfig.baseUrl, prod);
  });

  test('still reports unreachable when re-resolving finds nothing', () async {
    final client = serverAt(null);
    ApiConfig.probeClientFactory = () => client;

    expect(await serviceWith(client).checkHealth(), isFalse);
    expect(ApiConfig.baseUrl, prod, reason: 'production stays the default');
  });

  test('concurrent callers share one round of probing', () async {
    var clientsBuilt = 0;
    ApiConfig.probeClientFactory = () {
      clientsBuilt++;
      return serverAt(loopback);
    };

    await Future.wait([
      ApiConfig.refresh(),
      ApiConfig.refresh(),
      ApiConfig.refresh(),
    ]);

    expect(clientsBuilt, 1);
    expect(ApiConfig.baseUrl, loopback);
  });

  test('a later refresh probes again rather than reusing the first', () async {
    var clientsBuilt = 0;
    ApiConfig.probeClientFactory = () {
      clientsBuilt++;
      return serverAt(loopback);
    };

    await ApiConfig.refresh();
    await ApiConfig.refresh();

    expect(clientsBuilt, 2, reason: 'the in-flight probe must not be cached');
  });
}
