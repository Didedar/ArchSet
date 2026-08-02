import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:archset_r2/core/localization/app_strings.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/auth/pages/sign_in_email_page.dart';
import 'package:archset_r2/presentation/auth/pages/welcome_page.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockLocaleBloc extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

class _MockSessionCubit extends MockCubit<AppSession> implements SessionCubit {}

/// The login screen used to be a dead end: [SessionGate] only shows it in
/// [SessionUnauthenticated], and nothing on it could move the session out of
/// that state except a successful sign-in. A user who did not want an account
/// had no way back into the (offline-first) diary.
void main() {
  late _MockAuthBloc authBloc;
  late _MockLocaleBloc localeBloc;
  late _MockSessionCubit sessionCubit;

  const locale = Locale('en');
  final guestLabel = AppStrings.tr(locale, AppStrings.continueAsGuest);

  setUp(() {
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );

    localeBloc = _MockLocaleBloc();
    whenListen(
      localeBloc,
      const Stream<LocaleState>.empty(),
      initialState: const LocaleState(locale),
    );

    sessionCubit = _MockSessionCubit();
    whenListen(
      sessionCubit,
      const Stream<AppSession>.empty(),
      initialState: const SessionUnauthenticated(),
    );
    when(() => sessionCubit.continueAsGuest()).thenReturn(null);
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<LocaleBloc>.value(value: localeBloc),
          BlocProvider<SessionCubit>.value(value: sessionCubit),
        ],
        child: MaterialApp(home: page),
      ),
    );
    // WelcomePage staggers its entrance behind a 500ms post-frame delay;
    // settle past it so the guest button is at its final offset.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  group('WelcomePage', () {
    testWidgets('offers a way into the app without an account', (tester) async {
      await pumpPage(tester, const WelcomePage());

      expect(find.text(guestLabel), findsOneWidget);
    });

    testWidgets('tapping it drops the session to guest', (tester) async {
      await pumpPage(tester, const WelcomePage());

      await tester.tap(find.text(guestLabel));
      await tester.pump();

      verify(() => sessionCubit.continueAsGuest()).called(1);
    });

    // The page used to pin its column to exactly the screen height, so the
    // surrounding SingleChildScrollView could never scroll -- adding the
    // guest button just pushed the column past the bottom on short screens.
    //
    // Only *vertical* overflow is asserted: the gradient buttons overflow
    // horizontally at these widths under the test font (which renders every
    // glyph one em wide), and they do so on the unmodified page too, so it is
    // a test-harness artifact rather than something this change introduced.
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      testWidgets(
        'does not overflow vertically at ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final errors = <String>[];
          final previousOnError = FlutterError.onError;
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString());
          addTearDown(() => FlutterError.onError = previousOnError);

          await pumpPage(tester, const WelcomePage());

          expect(
            errors.where(
              (e) => e.contains('overflowed') && e.contains('bottom'),
            ),
            isEmpty,
            reason: 'WelcomePage should scroll, not overflow, when short',
          );
          expect(find.text(guestLabel), findsOneWidget);
        },
      );
    }
  });

  group('SignInEmailPage', () {
    testWidgets('offers the same escape hatch on the sign-in/register form', (
      tester,
    ) async {
      await pumpPage(tester, const SignInEmailPage());

      expect(find.text(guestLabel), findsOneWidget);
    });

    testWidgets('tapping it drops the session to guest', (tester) async {
      await pumpPage(tester, const SignInEmailPage());

      await tester.tap(find.text(guestLabel));
      await tester.pump();

      verify(() => sessionCubit.continueAsGuest()).called(1);
    });

    // Reported from a real device: opening the keyboard on the sign-in form
    // overflowed the page by 117px, because the body was a bare Column with
    // no scroll view -- Scaffold shrinks the body by the keyboard inset, and
    // the fixed-height fields had nowhere to go.
    testWidgets('does not overflow when the keyboard covers the bottom half', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final errors = <String>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());
      addTearDown(() => FlutterError.onError = previousOnError);

      await pumpPage(tester, const SignInEmailPage());

      // Keyboard up: ~45% of the screen, which is typical on Android.
      tester.view.viewInsets = const FakeViewPadding(bottom: 1050);
      await tester.pumpAndSettle();

      expect(
        errors.where((e) => e.contains('overflowed') && e.contains('bottom')),
        isEmpty,
        reason: 'the sign-in form should scroll behind the keyboard',
      );
    });

    testWidgets(
      'tapping it from a pushed sign-in page also unwinds back to the root '
      'route, so the auth screen does not linger over the diary',
      (tester) async {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<LocaleBloc>.value(value: localeBloc),
              BlocProvider<SessionCubit>.value(value: sessionCubit),
            ],
            child: const MaterialApp(home: WelcomePage()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // Reach the sign-in page the way a user does.
        await tester.tap(
          find.text(AppStrings.tr(locale, AppStrings.signInEmail)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SignInEmailPage), findsOneWidget);

        await tester.tap(find.text(guestLabel));
        await tester.pumpAndSettle();

        verify(() => sessionCubit.continueAsGuest()).called(1);
        expect(find.byType(SignInEmailPage), findsNothing);
        expect(find.byType(WelcomePage), findsOneWidget);
      },
    );
  });
}
