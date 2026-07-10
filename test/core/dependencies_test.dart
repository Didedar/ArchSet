import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/repository/secure_storage_locale_repository.dart';
import 'package:archset_r2/data/repository/secure_storage_theme_repository.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/presentation/auth/auth_dependencies.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:archset_r2/presentation/locale/locale_dependencies.dart';
import 'package:archset_r2/presentation/theme/theme_dependencies.dart';
import '../support/fake_app_database.dart';

void main() {
  test('exposes every feature dependency container it was built with', () {
    final storage = const FlutterSecureStorage();
    final core = CoreDependencies(
      database: FakeAppDatabase(),
      secureStorage: storage,
      logger: Logger(),
    );
    final theme = ThemeDependencies(
      repository: SecureStorageThemeRepository(storage: storage),
    );
    final locale = LocaleDependencies(
      repository: SecureStorageLocaleRepository(storage: storage),
    );
    final auth = AuthDependencies(
      repository: AuthService(database: core.database),
    );

    final dependencies = Dependencies(
      core: core,
      theme: theme,
      locale: locale,
      auth: auth,
    );

    expect(dependencies.core, same(core));
    expect(dependencies.theme, same(theme));
    expect(dependencies.locale, same(locale));
    expect(dependencies.auth, same(auth));
  });
}
