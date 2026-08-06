import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart' as bloc_concurrency;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../composition_root.dart';
import '../dependencies.dart';
import '../di/app_scope.dart';
import '../logging/logger.dart';
import '../logging/printing_log_observer.dart';
import '../../data/services/api_service.dart';
import 'app_bloc_observer.dart';
import 'root_context.dart';
import 'startup_error_screen.dart';

/// Boots the app: guarded zone → Flutter binding → global error hooks →
/// Bloc wiring → [CompositionRoot] → render (or a retry screen on
/// failure). `main.dart` only calls [initializeAndRun].
class AppRunner {
  const AppRunner();

  Future<void> initializeAndRun() async {
    final logger = Logger();
    if (!kReleaseMode) logger.addObserver(const PrintingLogObserver());

    runZonedGuarded(
      () async {
        final binding = WidgetsFlutterBinding.ensureInitialized();
        binding.deferFirstFrame();

        FlutterError.onError = (details) {
          logger.error(
            details.exceptionAsString(),
            details.exception,
            details.stack,
          );
        };
        PlatformDispatcher.instance.onError = (error, stackTrace) {
          logger.error('Uncaught platform error', error, stackTrace);
          return true;
        };

        Bloc.observer = AppBlocObserver(logger);
        Bloc.transformer = bloc_concurrency.sequential();

        await ApiConfig.init();
        logger.info('API base URL: ${ApiConfig.baseUrl}');

        await _composeAndRun(binding, logger);
      },
      (error, stackTrace) =>
          logger.error('Uncaught zone error', error, stackTrace),
    );
  }

  Future<void> _composeAndRun(WidgetsBinding binding, Logger logger) async {
    try {
      final Dependencies dependencies = await CompositionRoot(
        logger,
      ).initDependencies();
      binding.allowFirstFrame();
      runApp(AppScope(dependencies: dependencies, child: const RootContext()));
    } catch (error, stackTrace) {
      logger.error('Failed to initialize dependencies', error, stackTrace);
      binding.allowFirstFrame();
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StartupErrorScreen(
            error: error,
            stackTrace: stackTrace,
            onRetry: () => _composeAndRun(binding, logger),
          ),
        ),
      );
    }
  }
}
