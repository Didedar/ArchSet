import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/repository/secure_storage_theme_repository.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/theme/theme_dependencies_builder.dart';
import '../../support/fake_app_database.dart';

void main() {
  test('builds a repository wired to the core secure storage', () {
    final core = CoreDependencies(
      database: FakeAppDatabase(),
      secureStorage: const FlutterSecureStorage(),
      logger: Logger(),
    );

    final deps = ThemeDependenciesBuilder.build(core);

    expect(deps.repository, isA<SecureStorageThemeRepository>());
  });
}
