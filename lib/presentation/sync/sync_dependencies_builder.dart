import '../../data/services/api_service.dart';
import '../../data/services/sync_service.dart';
import '../auth/auth_dependencies.dart';
import '../core_deps/core_dependencies.dart';
import 'sync_dependencies.dart';

abstract class SyncDependenciesBuilder {
  static SyncDependencies build(CoreDependencies core, AuthDependencies auth) {
    final apiService = ApiService(authService: auth.repository);
    return SyncDependencies(
      service: SyncService(apiService: apiService, database: core.database),
    );
  }
}
