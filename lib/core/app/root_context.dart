import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../../presentation/auth/pages/splash_page.dart';
import '../../presentation/locale/bloc/locale_bloc.dart';
import '../../presentation/theme/bloc/theme_bloc.dart';

/// UI host mounted under [AppScope]. Still wraps a nested [ProviderScope]
/// internally for the features that haven't migrated off Riverpod yet
/// (notes/folders — Phase 4; audio/transcription/editor — Phase 5), which
/// are reached via navigation rather than mounted directly here.
/// `themeMode`/`locale` now come from [ThemeBloc]/[LocaleBloc] (both live
/// above this in [AppScope]'s MultiBlocProvider) instead of their old
/// Riverpod providers. The nested scope goes away entirely once every
/// feature has migrated.
class RootContext extends StatelessWidget {
  const RootContext({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _LegacyRiverpodApp());
  }
}

class _LegacyRiverpodApp extends StatelessWidget {
  const _LegacyRiverpodApp();

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
