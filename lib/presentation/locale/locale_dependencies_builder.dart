import '../../data/repository/secure_storage_locale_repository.dart';
import '../core_deps/core_dependencies.dart';
import 'locale_dependencies.dart';

abstract class LocaleDependenciesBuilder {
  static LocaleDependencies build(CoreDependencies core) {
    return LocaleDependencies(
      repository: SecureStorageLocaleRepository(storage: core.secureStorage),
    );
  }
}
