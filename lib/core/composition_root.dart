import '../presentation/core_deps/core_dependencies_builder.dart';
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

      stopwatch.stop();
      logger.info(
        'Dependencies initialized in ${stopwatch.elapsedMilliseconds}ms',
      );
      return Dependencies(core: core);
    } catch (error, stackTrace) {
      logger.error('Failed to initialize dependencies', error, stackTrace);
      rethrow;
    }
  }
}
