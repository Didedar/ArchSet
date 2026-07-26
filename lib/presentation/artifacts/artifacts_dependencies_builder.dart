import '../../data/repository/artifacts_repository.dart';
import '../core_deps/core_dependencies.dart';
import 'artifacts_dependencies.dart';

abstract class ArtifactsDependenciesBuilder {
  static ArtifactsDependencies build(CoreDependencies core) {
    return ArtifactsDependencies(
      repository: ArtifactsRepository(core.database),
    );
  }
}
