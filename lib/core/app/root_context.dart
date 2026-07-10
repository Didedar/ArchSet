import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../../presentation/providers/locale_provider.dart';
import '../../presentation/providers/sync_provider.dart';
import '../../presentation/providers/theme_provider.dart';
import '../../splash_page.dart';

/// UI host mounted under [AppScope]. For now this still wraps a nested
/// [ProviderScope] internally — nothing has migrated off Riverpod yet, so
/// this preserves the old `MyApp` behavior exactly. The nested scope goes
/// away in the cleanup phase once every feature has its own BLoC.
class RootContext extends StatelessWidget {
  const RootContext({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _LegacyRiverpodApp());
  }
}

class _LegacyRiverpodApp extends ConsumerWidget {
  const _LegacyRiverpodApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps SyncService alive by watching its provider.
    ref.watch(syncServiceProvider);

    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'ArchSet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
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
  }
}
