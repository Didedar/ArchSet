import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
import 'package:archset_r2/presentation/artifacts/artifacts_dependencies_builder.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_app_database.dart';

void main() {
  test('builds an ArtifactsRepository wired to the core database', () {
    final database = FakeAppDatabase();
    final core = CoreDependencies(
      database: database,
      secureStorage: const FlutterSecureStorage(),
      logger: Logger(),
    );

    final deps = ArtifactsDependenciesBuilder.build(core);

    expect(deps.repository, isA<ArtifactsRepository>());
    expect(deps.repository.database, same(database));
  });
}
