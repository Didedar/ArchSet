import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Installs an in-memory handler for `flutter_secure_storage`'s method
/// channel, so tests can construct a real `FlutterSecureStorage()` without
/// hitting a `MissingPluginException`. Call once per test (e.g. in `setUp`).
/// Returns the backing map, useful for asserting on stored values directly.
Map<String, String> installFakeSecureStorage() {
  final values = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    switch (call.method) {
      case 'read':
        return values[call.arguments['key']];
      case 'write':
        values[call.arguments['key'] as String] =
            call.arguments['value'] as String;
        return null;
      case 'delete':
        values.remove(call.arguments['key']);
        return null;
      case 'deleteAll':
        values.clear();
        return null;
      default:
        return null;
    }
  });
  return values;
}
