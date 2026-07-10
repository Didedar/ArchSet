import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../dependencies.dart';
import '../../presentation/core_deps/core_dependencies.dart';

/// The DI boundary. Exposes [Dependencies] and each feature container to
/// the widget tree below it via `package:provider`.
class AppScope extends StatelessWidget {
  const AppScope({required this.dependencies, required this.child, super.key});

  final Dependencies dependencies;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dependencies>.value(value: dependencies),
        Provider<CoreDependencies>.value(value: dependencies.core),
      ],
      child: child,
    );
  }
}

extension AppScopeContext on BuildContext {
  Dependencies get di => read<Dependencies>();
  CoreDependencies get coreDependencies => read<CoreDependencies>();
}
