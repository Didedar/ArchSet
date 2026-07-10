import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import '../support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakePathProvider);

  test('exposes the core dependencies container it was built with', () {
    final core = CoreDependencies(
      database: AppDatabase(),
      secureStorage: const FlutterSecureStorage(),
      logger: Logger(),
    );

    final dependencies = Dependencies(core: core);

    expect(dependencies.core, same(core));
  });
}
