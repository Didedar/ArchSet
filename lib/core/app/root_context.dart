import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../theme/app_theme.dart';
import '../../presentation/locale/bloc/locale_bloc.dart';
import '../../presentation/session/bloc/session_cubit.dart';
import '../../presentation/session/session_gate.dart';
import '../../presentation/theme/bloc/theme_bloc.dart';

/// Root navigator key. Lets the global session-loss listener below reset
/// navigation from outside the widget tree (no [BuildContext] needed).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);

/// UI host mounted under [AppScope]. `themeMode`/`locale` come from
/// [ThemeBloc]/[LocaleBloc] (both live above this in [AppScope]'s
/// MultiBlocProvider).
///
/// The root screen itself is driven declaratively by [SessionCubit] via
/// [SessionGate] (see `home:` below). On top of that, this widget resets
/// navigation back to the root screen whenever the session becomes
/// authenticated or unauthenticated (login, explicit logout, or a lost /
/// expired session), so a screen pushed under the old session never lingers
/// behind the new one. It deliberately does nothing else here -- in
/// particular it never dispatches a sync: claiming guest data on login is a
/// separate, later step that must run before any sync.
class RootContext extends StatelessWidget {
  const RootContext({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionCubit, AppSession>(
      listenWhen: (previous, current) =>
          current is SessionAuthenticated || current is SessionUnauthenticated,
      listener: (context, state) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      },
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return BlocBuilder<LocaleBloc, LocaleState>(
            builder: (context, localeState) {
              return MaterialApp(
                navigatorKey: rootNavigatorKey,
                title: 'ArchSet',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeState.mode,
                locale: localeState.locale,
                supportedLocales: const [
                  Locale('en'),
                  Locale('ru'),
                  Locale('kk'),
                  Locale('zh'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  FlutterQuillLocalizations.delegate,
                ],
                home: const SessionGate(),
                builder: (context, child) => GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
