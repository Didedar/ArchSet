import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:provider/provider.dart';

import 'package:archset_r2/core/dependencies.dart';
import 'package:archset_r2/core/localization/app_strings.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
import 'package:archset_r2/presentation/notes/notes_dependencies.dart';
import 'package:archset_r2/data/services/auth_service.dart' show AuthUser;
import 'package:archset_r2/data/services/sync_service.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/auth/pages/sign_in_email_page.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/pages/legal_document_page.dart';
import 'package:archset_r2/core/legal/legal_text.dart';
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

class _MockNotesRepository extends Mock implements NotesRepository {}

/// Mocked whole rather than constructed: [Dependencies] has ten required
/// fields and this page reaches for exactly one of them.
class _FakeDependencies extends Mock implements Dependencies {}

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
  late _MockNotesRepository notesRepository;
  late _FakeDependencies dependencies;
  late StreamController<SyncState> syncStateController;

  // A real uuid and a real address, not '1'/'a@b.com': the settings rows put
  // these opposite their label, and a one-character id hid the fact that a
  // 36-character one leaves the label nothing.
  final user = AuthUser(
    id: '302ae3b7-279e-4348-a8e1-6a3616f0d2f9',
    email: 'noname1@example.com',
    createdAt: DateTime(2026),
  );

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
    when(() => sessionCubit.deleteAccount()).thenAnswer((_) async {});

    // Nothing pending by default, so the existing sign-out tests below see
    // the confirm dialog directly, exactly as before this warning existed.
    notesRepository = _MockNotesRepository();
    when(() => notesRepository.pendingSyncCount()).thenAnswer((_) async => 0);
    when(
      () => notesRepository.wipeAllLocalData(),
    ).thenAnswer((_) async {});

    dependencies = _FakeDependencies();
    when(
      () => dependencies.notes,
    ).thenReturn(NotesDependencies(repository: notesRepository));
  });

  tearDown(() async {
    await syncStateController.close();
  });

  /// Re-stubs the session mock. The last `whenListen` wins, so tests can
  /// override the authenticated default set up in [setUp].
  void givenSession(AppSession session) {
    whenListen(
      sessionCubit,
      const Stream<AppSession>.empty(),
      initialState: session,
    );
  }

  Future<void> pumpSettingsPage(WidgetTester tester) {
    return tester.pumpWidget(
      Provider<Dependencies>.value(
        value: dependencies,
        child: MultiBlocProvider(
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

  /// Settings used to read [AuthBloc], which nothing in the app ever
  /// bootstraps -- `AuthCheckRequested` is dispatched nowhere since routing
  /// moved to [SessionCubit]. So `AuthBloc` sits at [AuthInitial] both for a
  /// guest *and* for a signed-in user who has just restarted the app, and the
  /// page rendered "Unknown" ids plus a Sign Out button in both cases. These
  /// tests pin the page to [SessionCubit], the actual source of truth.
  group('account state is read from SessionCubit, not AuthBloc', () {
    String s(String key) => AppStrings.tr(locale, key);

    testWidgets('a guest is shown as having no account', (tester) async {
      givenSession(const SessionGuest());
      await pumpSettingsPage(tester);

      expect(find.text(s(AppStrings.guestMode)), findsWidgets);
      expect(find.text(s(AppStrings.noAccount)), findsOneWidget);
      expect(find.text(s(AppStrings.guestModeDescription)), findsOneWidget);
      expect(find.text(s(AppStrings.signInOrCreateAccount)), findsOneWidget);

      // The bug the user reported: none of this belongs to someone who never
      // signed in.
      expect(find.text(s(AppStrings.unknown)), findsNothing);
      expect(find.text(s(AppStrings.signOut)), findsNothing);
      expect(find.text(s(AppStrings.deleteAccount)), findsNothing);
      expect(find.text(s(AppStrings.signedIn)), findsNothing);
    });

    testWidgets(
      'a signed-in user is shown as having an account even when AuthBloc is '
      'still AuthInitial (i.e. after an app restart)',
      (tester) async {
        // Exactly the real post-restart wiring: SessionCubit.bootstrap()
        // restored the user, AuthBloc was never told anything.
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: const AuthInitial(),
        );
        givenSession(SessionAuthenticated(user));
        await pumpSettingsPage(tester);

        expect(find.text(s(AppStrings.signedIn)), findsOneWidget);
        expect(find.text(user.email), findsWidgets);
        expect(find.text(user.id), findsOneWidget);
        expect(find.text(s(AppStrings.signOut)), findsOneWidget);
        expect(find.text(s(AppStrings.deleteAccount)), findsOneWidget);

        expect(find.text(s(AppStrings.unknown)), findsNothing);
        expect(find.text(s(AppStrings.guestMode)), findsNothing);
      },
    );

    testWidgets('tapping Terms of Use opens the terms page', (tester) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final row = find.text(s(AppStrings.termsOfUse));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(find.text(LegalText.termsOfUse), findsOneWidget);
    });

    testWidgets('tapping Privacy Policy opens the privacy page', (
      tester,
    ) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final row = find.text(s(AppStrings.privacyPolicy));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(find.text(LegalText.privacyPolicy), findsOneWidget);
    });

    testWidgets('the feature request row no longer exists', (tester) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      expect(find.byIcon(Icons.card_membership_outlined), findsNothing);
    });

    testWidgets(
      'confirming Delete Account calls SessionCubit.deleteAccount() then '
      'wipes local data',
      (tester) async {
        givenSession(SessionAuthenticated(user));
        await pumpSettingsPage(tester);

        final row = find.text(s(AppStrings.deleteAccount));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(
          find.text(s(AppStrings.deleteAccountConfirmMessage)),
          findsOneWidget,
        );

        // Delete is the dialog's last TextButton (Cancel is first).
        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await tester.pumpAndSettle();

        verify(() => sessionCubit.deleteAccount()).called(1);
        verify(() => notesRepository.wipeAllLocalData()).called(1);
      },
    );

    testWidgets('declining the Delete Account confirmation deletes nothing', (
      tester,
    ) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final row = find.text(s(AppStrings.deleteAccount));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      // Cancel is the dialog's first TextButton.
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => sessionCubit.deleteAccount());
      verifyNever(() => notesRepository.wipeAllLocalData());
    });

    testWidgets(
      'a failed Delete Account shows an error and does not wipe local data',
      (tester) async {
        when(
          () => sessionCubit.deleteAccount(),
        ).thenThrow(Exception('network error'));
        givenSession(SessionAuthenticated(user));
        await pumpSettingsPage(tester);

        final row = find.text(s(AppStrings.deleteAccount));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              )
              .last,
        );
        await tester.pumpAndSettle();

        expect(find.text(s(AppStrings.deleteAccountFailed)), findsOneWidget);
        verifyNever(() => notesRepository.wipeAllLocalData());
      },
    );

    testWidgets('a lost/expired session is treated as no account', (
      tester,
    ) async {
      givenSession(const SessionUnauthenticated());
      await pumpSettingsPage(tester);

      expect(find.text(s(AppStrings.noAccount)), findsOneWidget);
      expect(find.text(s(AppStrings.signOut)), findsNothing);
      expect(find.text(s(AppStrings.unknown)), findsNothing);
    });

    testWidgets('signing out with unsynced entries warns before logging out', (
      tester,
    ) async {
      when(
        () => notesRepository.pendingSyncCount(),
      ).thenAnswer((_) async => 12);
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final signOut = find.text(s(AppStrings.signOut));
      await tester.ensureVisible(signOut);
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();

      expect(find.text(s(AppStrings.unsyncedWarningTitle)), findsOneWidget);
      // The warning precedes the normal confirm dialog, and cannot itself
      // log anyone out.
      expect(find.text(s(AppStrings.signOutConfirmMessage)), findsNothing);
      verifyNever(() => sessionCubit.logout());
    });

    testWidgets('declining the unsynced warning does not sign out', (
      tester,
    ) async {
      when(() => notesRepository.pendingSyncCount()).thenAnswer((_) async => 3);
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final signOut = find.text(s(AppStrings.signOut));
      await tester.ensureVisible(signOut);
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();

      // Cancel is the dialog's first TextButton.
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => sessionCubit.logout());
    });

    testWidgets('with nothing pending, sign-out goes straight to confirm', (
      tester,
    ) async {
      givenSession(SessionAuthenticated(user));
      await pumpSettingsPage(tester);

      final signOut = find.text(s(AppStrings.signOut));
      await tester.ensureVisible(signOut);
      await tester.pumpAndSettle();
      await tester.tap(signOut);
      await tester.pumpAndSettle();

      expect(find.text(s(AppStrings.unsyncedWarningTitle)), findsNothing);
      expect(find.text(s(AppStrings.signOutConfirmMessage)), findsOneWidget);
    });

    testWidgets('the guest card opens the sign-in page', (tester) async {
      givenSession(const SessionGuest());
      await pumpSettingsPage(tester);

      final button = find.text(s(AppStrings.signInOrCreateAccount));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(SignInEmailPage), findsOneWidget);
    });
  });

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

  /// Every locale ships in the app, and the app supports phones down to about
  /// 320pt wide. A settings row that fits an English label on a roomy screen
  /// can still run off the edge once translated, or on a small handset -- and
  /// an overflow there is a red-and-yellow stripe across a screen people open
  /// to sign out.
  for (final code in AppStrings.supportedLanguageCodes) {
    for (final width in const [320.0, 411.0]) {
      testWidgets('fits at ${width.toInt()}pt wide in "$code"', (tester) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        localeBloc = _MockLocaleBloc();
        whenListen(
          localeBloc,
          const Stream<LocaleState>.empty(),
          initialState: LocaleState(Locale(code)),
        );

        await pumpSettingsPage(tester);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'settings overflowed at ${width.toInt()}pt in "$code"',
        );
      });
    }
  }

  /// The sweep above cannot catch this: a label squeezed to nothing *wraps*,
  /// and wrapping is not an overflow. "User ID" came out stacked one letter
  /// per line beside a user id that had claimed the whole row.
  ///
  /// Measured as width rather than line count on purpose. Line count depends
  /// on the font, and the test font's glyphs are fixed-width and far wider
  /// than Inter's -- it would report a wrap that no phone shows. Width says
  /// the thing that actually went wrong: the label was left with nothing.
  testWidgets('a long value never crushes its label', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSettingsPage(tester);
    await tester.pumpAndSettle();

    final label = find.text(AppStrings.tr(locale, AppStrings.userId));
    expect(label, findsOneWidget);
    expect(
      tester.getSize(label).width,
      greaterThan(80),
      reason: 'the 36-character user id beside it took the whole row',
    );
  });
}
