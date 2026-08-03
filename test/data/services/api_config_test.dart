import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:archset_r2/data/services/api_service.dart';

/// Picking which backend to talk to in development.
///
/// The old logic tried production, then fell back to a single hardcoded
/// `127.0.0.1:8000`. On a physical Android phone that address is the *phone*,
/// so it only worked while an `adb reverse` tunnel happened to be alive -- and
/// that tunnel dies on every cable unplug, phone reboot and adb restart, with
/// nothing re-creating it. The result was a "Connection refused" that came
/// back constantly and looked like the backend was down.
///
/// Now several candidates are tried and the first that answers wins, so the
/// same build works over the USB tunnel, over Wi-Fi, or on an emulator without
/// anyone remembering a ritual.
void main() {
  const prod = 'https://archset-backend-production.up.railway.app';
  const loopback = 'http://127.0.0.1:8000';
  const lan = 'http://10.0.0.5:8000';

  /// A backend that answers only at [reachable]; everything else refuses.
  MockClient serverAt(String? reachable) {
    return MockClient((request) async {
      final origin = '${request.url.scheme}://${request.url.authority}';
      if (reachable != null && origin == reachable) {
        return http.Response('{"status":"ok"}', 200);
      }
      throw const SocketException('Connection refused');
    });
  }

  test(
    'production wins when it is up, without probing anything local',
    () async {
      var localProbes = 0;
      final client = MockClient((request) async {
        final origin = '${request.url.scheme}://${request.url.authority}';
        if (origin == prod) return http.Response('{}', 200);
        localProbes++;
        throw const SocketException('refused');
      });

      final resolved = await ApiConfig.resolveBaseUrl(
        client: client,
        candidates: const [loopback, lan],
      );

      expect(resolved, prod);
      expect(localProbes, 0, reason: 'no reason to probe dev hosts');
    },
  );

  test('falls back to the loopback host when the tunnel is up', () async {
    final resolved = await ApiConfig.resolveBaseUrl(
      client: serverAt(loopback),
      candidates: const [loopback, lan],
    );

    expect(resolved, loopback);
  });

  test('reaches the machine over Wi-Fi when the tunnel is down', () async {
    // The case that was broken: no adb reverse, but the laptop is on the same
    // network and perfectly reachable.
    final resolved = await ApiConfig.resolveBaseUrl(
      client: serverAt(lan),
      candidates: const [loopback, lan],
    );

    expect(resolved, lan);
  });

  test('prefers the earlier candidate when several answer', () async {
    final client = MockClient((_) async => http.Response('{}', 200));

    final resolved = await ApiConfig.resolveBaseUrl(
      client: client,
      candidates: const [loopback, lan],
    );

    expect(resolved, prod, reason: 'production is still checked first');
  });

  test('a non-200 from production is treated as unusable', () async {
    final client = MockClient((request) async {
      final origin = '${request.url.scheme}://${request.url.authority}';
      if (origin == prod) return http.Response('bad gateway', 502);
      if (origin == lan) return http.Response('{}', 200);
      throw const SocketException('refused');
    });

    final resolved = await ApiConfig.resolveBaseUrl(
      client: client,
      candidates: const [loopback, lan],
    );

    expect(resolved, lan);
  });

  test('keeps production as the answer when nothing at all responds', () async {
    // Genuinely offline. Production is the honest default: the app is
    // offline-first and will retry, and pointing at a dev host that is not
    // there would strand a real user on a laptop address forever.
    final resolved = await ApiConfig.resolveBaseUrl(
      client: serverAt(null),
      candidates: const [loopback, lan],
    );

    expect(resolved, prod);
  });

  test(
    'ignores an empty candidate, so an unset dart-define is harmless',
    () async {
      final resolved = await ApiConfig.resolveBaseUrl(
        client: serverAt(lan),
        candidates: const ['', lan],
      );

      expect(resolved, lan);
    },
  );
}
