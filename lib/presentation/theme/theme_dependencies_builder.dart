import '../../data/repository/secure_storage_theme_repository.dart';
import '../core_deps/core_dependencies.dart';
import 'theme_dependencies.dart';

abstract class ThemeDependenciesBuilder {
  static ThemeDependencies build(CoreDependencies core) {
    return ThemeDependencies(
      repository: SecureStorageThemeRepository(storage: core.secureStorage),
    );
  }
}
