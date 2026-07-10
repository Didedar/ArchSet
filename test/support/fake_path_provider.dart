import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Real [AppDatabase] opens its sqlite connection lazily via drift_flutter,
/// which asks `path_provider` for a directory — a platform-channel call
/// that fails outside a real device/simulator. Installing this fake lets
/// tests construct the real (singleton) [AppDatabase] without touching an
/// actual platform channel.
class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationSupportPath() async => _path;

  @override
  Future<String?> getTemporaryPath() async => _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

/// Call once per test (or in `setUp`) before anything touches [AppDatabase].
void installFakePathProvider({String path = '.dart_tool/test_app_support'}) {
  PathProviderPlatform.instance = FakePathProviderPlatform(path);
}
