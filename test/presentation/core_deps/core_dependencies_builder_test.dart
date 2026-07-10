import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/logging/logger.dart';
import 'package:archset_r2/presentation/core_deps/core_dependencies_builder.dart';
import '../../support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakePathProvider);

  test('builds a CoreDependencies wired to the given logger', () {
    final logger = Logger();

    final deps = CoreDependenciesBuilder.build(logger);

    expect(deps.logger, same(logger));
    expect(deps.database, isNotNull);
    expect(deps.secureStorage, isNotNull);
  });
}
