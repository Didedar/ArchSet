import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../dependencies.dart';
import '../../presentation/auth/bloc/auth_bloc.dart';
import '../../presentation/core_deps/core_dependencies.dart';
import '../../presentation/locale/bloc/locale_bloc.dart';
import '../../presentation/theme/bloc/theme_bloc.dart';

/// The DI boundary. Exposes [Dependencies]/[CoreDependencies] via
/// `package:provider`, and every global BLoC via [MultiBlocProvider].
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
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeBloc>(
            lazy: false,
            create: (_) => ThemeBloc(repository: dependencies.theme.repository)
              ..add(const ThemeLoadRequested()),
          ),
          BlocProvider<LocaleBloc>(
            lazy: false,
            create: (_) =>
                LocaleBloc(repository: dependencies.locale.repository)
                  ..add(const LocaleLoadRequested()),
          ),
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(repository: dependencies.auth.repository),
          ),
        ],
        child: child,
      ),
    );
  }
}

extension AppScopeContext on BuildContext {
  Dependencies get di => read<Dependencies>();
  CoreDependencies get coreDependencies => read<CoreDependencies>();
}
