import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/logging/logger.dart';
import '../../data/current_owner_holder.dart';
import '../../data/database/app_database.dart';
import 'core_dependencies.dart';

abstract class CoreDependenciesBuilder {
  /// [AppDatabase] is still constructed via its singleton factory here (not
  /// a plain constructor) — it stays that way until every other caller of
  /// that factory is migrated off it too (Phase 4), so old and new code can
  /// safely share the one cached instance in the meantime.
  ///
  /// [CurrentOwnerHolder] is constructed exactly once here and threaded
  /// through [CoreDependencies] to every feature builder that needs it
  /// (notes, editor) plus [SessionCubit] in `AppScope`, so they all share
  /// the one instance.
  static CoreDependencies build(Logger logger) {
    return CoreDependencies(
      database: AppDatabase(),
      secureStorage: const FlutterSecureStorage(),
      logger: logger,
      currentOwner: CurrentOwnerHolder(),
    );
  }
}
