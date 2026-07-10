import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import '../../support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakePathProvider);

  test('holds the database, secure storage, and logger it was built with', () {
    final database = AppDatabase();
    const storage = FlutterSecureStorage();
    final logger = Logger();

    final deps = CoreDependencies(
      database: database,
      secureStorage: storage,
      logger: logger,
    );

    expect(deps.database, same(database));
    expect(deps.secureStorage, same(storage));
    expect(deps.logger, same(logger));
  });
}
