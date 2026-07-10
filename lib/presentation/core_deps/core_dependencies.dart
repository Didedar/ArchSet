import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/logging/logger.dart';
import '../../data/database/app_database.dart';

/// Cross-cutting dependencies every other feature container is built from.
class CoreDependencies {
  const CoreDependencies({
    required this.database,
    required this.secureStorage,
    required this.logger,
  });

  final AppDatabase database;
  final FlutterSecureStorage secureStorage;
  final Logger logger;
}
