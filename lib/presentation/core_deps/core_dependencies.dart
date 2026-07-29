import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/logging/logger.dart';
import '../../data/current_owner_holder.dart';
import '../../data/database/app_database.dart';

/// Cross-cutting dependencies every other feature container is built from.
class CoreDependencies {
  CoreDependencies({
    required this.database,
    required this.secureStorage,
    required this.logger,
    CurrentOwnerHolder? currentOwner,
  }) : currentOwner = currentOwner ?? CurrentOwnerHolder();

  final AppDatabase database;
  final FlutterSecureStorage secureStorage;
  final Logger logger;

  /// The single [CurrentOwnerHolder] instance shared by [SessionCubit] and
  /// every [NotesRepository], so local reads/writes always agree on who the
  /// current account is.
  final CurrentOwnerHolder currentOwner;
}
