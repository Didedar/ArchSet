import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:archset_r2/core/localization/app_strings.dart';
import 'package:archset_r2/data/services/auth_service.dart' show AuthUser;
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/pages/settings_page.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';
import 'package:archset_r2/presentation/sync/bloc/sync_bloc.dart';
import 'package:archset_r2/presentation/theme/bloc/theme_bloc.dart';
import 'package:archset_r2/presentation/transcription/bloc/transcription_bloc.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState>
    implements ThemeBloc {}

class _MockLocaleBloc extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

class _MockTranscriptionBloc
    extends MockBloc<TranscriptionEvent, TranscriptionState>
    implements TranscriptionBloc {}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState>
    implements SyncBloc {}

class _MockSessionCubit extends MockCubit<AppSession> implements SessionCubit {}

/// Regression coverage for I1: the pre-logout sync in
/// `SettingsPage._handleSignOut` used to await only `SyncSuccess`/
/// `SyncFailure`. Offline/unreachable sync mirrors `SyncOffline` on the
/// bloc's stream (never Success/Failure), and a guest/no-op sync emits no
/// terminal state at all -- either way `firstWhere` never completed, so
/// `SessionCubit.logout()` was never reached and the user could not sign
/// out while offline.
void main() {
  late _MockAuthBloc authBloc;
  late _MockThemeBloc themeBloc;
  late _MockLocaleBloc localeBloc;
  late _MockTranscriptionBloc transcriptionBloc;
  late _MockSyncBloc syncBloc;
  late _MockSessionCubit sessionCubit;
  late StreamController<SyncState> syncStateController;

  final user = AuthUser(id: '1', email: 'a@b.com', createdAt: DateTime(2026));

  setUp(() {
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(user),
    );

    themeBloc = _MockThemeBloc();
    whenListen(
      themeBloc,
      const Stream<ThemeState>.empty(),
      initialState: const ThemeState(ThemeMode.system),
    );

    localeBloc = _MockLocaleBloc();
    whenListen(
      localeBloc,
      const Stream<LocaleState>.empty(),
      initialState: const LocaleState(Locale('en')),
    );

    transcriptionBloc = _MockTranscriptionBloc();
    whenListen(
      transcriptionBloc,
      const Stream<TranscriptionState>.empty(),
      initialState: const TranscriptionState(),
    );

    syncStateController = StreamController<SyncState>.broadcast();
    syncBloc = _MockSyncBloc();
    whenListen(
      syncBloc,
      syncStateController.stream,
      initialState: const SyncIdle(),
    );

    sessionCubit = _MockSessionCubit();
    whenListen(
      sessionCubit,
      const Stream<AppSession>.empty(),
      initialState: SessionAuthenticated(user),
    );
    when(() => sessionCubit.logout()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await syncStateController.close();
  });

  Future<void> pumpSettingsPage(WidgetTester tester) {
    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<ThemeBloc>.value(value: themeBloc),
          BlocProvider<LocaleBloc>.value(value: localeBloc),
          BlocProvider<TranscriptionBloc>.value(value: transcriptionBloc),
          BlocProvider<SyncBloc>.value(value: syncBloc),
          BlocProvider<SessionCubit>.value(value: sessionCubit),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
  }

  const locale = Locale('en');

  /// Taps "Sign out" then confirms the dialog, leaving `_handleSignOut`
  /// suspended right at `await syncFinished` -- callers then drive
  /// `syncStateController` (or a timeout) to resolve it.
  Future<void> tapSignOutAndConfirm(WidgetTester tester) async {
    // The menu item sits below the fold on the default test surface, inside
    // the page's SingleChildScrollView.
    final signOutFinder = find.text(AppStrings.tr(locale, AppStrings.signOut));
    await tester.ensureVisible(signOutFinder);
    await tester.pumpAndSettle();
    await tester.tap(signOutFinder);
    await tester.pumpAndSettle();

    // Targeted by position, not text: the en locale table currently
    // (pre-existing, unrelated bug) labels this button "Sign Out" too, same
    // as the menu item, so text-matching would be ambiguous. Cancel is the
    // dialog's first TextButton, Confirm is the last.
    final confirmButton = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        )
        .last;
    await tester.tap(confirmButton);
    await tester.pump();
  }

  testWidgets(
    'signing out while offline (pre-logout sync ends in SyncOffline) still '
    'calls SessionCubit.logout() instead of hanging forever',
    (tester) async {
      await pumpSettingsPage(tester);
      await tapSignOutAndConfirm(tester);

      verifyNever(() => sessionCubit.logout());

      // Mirrors what SyncService.sync() does when offline/unreachable: the
      // status stream emits SyncOffline, never SyncSuccess/SyncFailure.
      syncStateController.add(const SyncOffline());
      await tester.pumpAndSettle();

      verify(() => sessionCubit.logout()).called(1);
    },
  );

  testWidgets(
    'signing out when the pre-logout sync never reaches a terminal state '
    '(e.g. guest no-op) still calls SessionCubit.logout() after the timeout',
    (tester) async {
      await pumpSettingsPage(tester);
      await tapSignOutAndConfirm(tester);

      verifyNever(() => sessionCubit.logout());

      // Nothing is ever pushed onto syncStateController -- the guest/no-op
      // branch of SyncService.sync() emits no status/result at all. Only the
      // safety-net timeout can unblock logout here.
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      verify(() => sessionCubit.logout()).called(1);
    },
  );

  testWidgets('signing out while a sync completes successfully still calls '
      'SessionCubit.logout() (existing online behavior preserved)', (
    tester,
  ) async {
    await pumpSettingsPage(tester);
    await tapSignOutAndConfirm(tester);

    syncStateController.add(
      SyncSuccess(SyncResult(status: SyncStatus.success)),
    );
    await tester.pumpAndSettle();

    verify(() => sessionCubit.logout()).called(1);
  });
}
