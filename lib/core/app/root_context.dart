import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../theme/app_theme.dart';
import '../../presentation/auth/pages/splash_page.dart';
import '../../presentation/locale/bloc/locale_bloc.dart';
import '../../presentation/theme/bloc/theme_bloc.dart';

/// UI host mounted under [AppScope]. `themeMode`/`locale` come from
/// [ThemeBloc]/[LocaleBloc] (both live above this in [AppScope]'s
/// MultiBlocProvider).
class RootContext extends StatelessWidget {
  const RootContext({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        return BlocBuilder<LocaleBloc, LocaleState>(
          builder: (context, localeState) {
            return MaterialApp(
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
              home: const SplashPage(),
              builder: (context, child) => GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}
