import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies_builder.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import '../../support/fake_app_database.dart';

void main() {
  test('builds a repository wired to the core database', () {
    final core = CoreDependencies(
      database: FakeAppDatabase(),
      secureStorage: const FlutterSecureStorage(),
      logger: Logger(),
    );

    final deps = AuthDependenciesBuilder.build(core);

    expect(deps.repository, isA<AuthService>());
  });
}
