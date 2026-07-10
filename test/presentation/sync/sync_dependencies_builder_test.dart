import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/sync/sync_dependencies_builder.dart';
import '../../support/fake_app_database.dart';
import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  test('builds a SyncService wired to core database and auth', () {
    final database = FakeAppDatabase();
    final core = CoreDependencies(
      database: database,
      secureStorage: const FlutterSecureStorage(),
      logger: Logger(),
    );
    final auth = AuthDependencies(
      repository: AuthService(database: database),
    );

    final deps = SyncDependenciesBuilder.build(core, auth);

    expect(deps.service, isA<SyncService>());
  });
}
