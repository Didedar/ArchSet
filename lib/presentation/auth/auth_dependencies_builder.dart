import '../../data/services/auth_service.dart';
import '../core_deps/core_dependencies.dart';
import 'auth_dependencies.dart';

abstract class AuthDependenciesBuilder {
  static AuthDependencies build(CoreDependencies core) {
    return AuthDependencies(
      repository: AuthService(database: core.database),
    );
  }
}
