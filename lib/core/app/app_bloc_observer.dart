import 'package:bloc/bloc.dart';
import '../logging/logger.dart';

/// Routes every Bloc transition and error through the same [Logger]
/// pipeline as Flutter/platform/zone errors, per the startup error map.
class AppBlocObserver extends BlocObserver {
  AppBlocObserver(this._logger);

  final Logger _logger;

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    _logger.info('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    _logger.error('${bloc.runtimeType} error', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
