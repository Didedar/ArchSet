import '../presentation/core_deps/core_dependencies.dart';

/// Aggregate of every feature's dependency container. Grows one field per
/// feature as each is migrated off Riverpod (auth, sync, notes, ...).
class Dependencies {
  const Dependencies({required this.core});

  final CoreDependencies core;
}
