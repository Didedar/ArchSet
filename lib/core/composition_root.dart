import '../presentation/auth/auth_dependencies_builder.dart';
import '../presentation/core_deps/core_dependencies_builder.dart';
import '../presentation/locale/locale_dependencies_builder.dart';
import '../presentation/sync/sync_dependencies_builder.dart';
import '../presentation/theme/theme_dependencies_builder.dart';
import 'dependencies.dart';
import 'logging/logger.dart';

/// Builds the [Dependencies] graph the app runs on. The only place feature
/// dependency builders are chained together.
class CompositionRoot {
  const CompositionRoot(this.logger);

  final Logger logger;

  Future<Dependencies> initDependencies() async {
    final stopwatch = Stopwatch()..start();
    logger.info('Initialization started...');
    try {
      final core = CoreDependenciesBuilder.build(logger);
      final theme = ThemeDependenciesBuilder.build(core);
      final locale = LocaleDependenciesBuilder.build(core);
      final auth = AuthDependenciesBuilder.build(core);
      final sync = SyncDependenciesBuilder.build(core, auth);

      stopwatch.stop();
      logger.info(
        'Dependencies initialized in ${stopwatch.elapsedMilliseconds}ms',
      );
      return Dependencies(
        core: core,
        theme: theme,
        locale: locale,
        auth: auth,
        sync: sync,
      );
    } catch (error, stackTrace) {
      logger.error('Failed to initialize dependencies', error, stackTrace);
      rethrow;
    }
  }
}
