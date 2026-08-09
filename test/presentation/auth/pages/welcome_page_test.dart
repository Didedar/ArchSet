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

void main() {
  late _MockAuthBloc authBloc;
  late _MockLocaleBloc localeBloc;
  late _MockSessionCubit sessionCubit;

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
      initialState: const LocaleState(Locale('en')),
    );

    sessionCubit = _MockSessionCubit();
    whenListen(
      sessionCubit,
      const Stream<AppSession>.empty(),
      initialState: const SessionGuest(),
    );
  });

  Future<void> pumpWelcomePage(WidgetTester tester) async {
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
    // WelcomePage staggers its entrance behind a 500ms post-frame delay;
    // settle past it so the buttons are at their final offset (see
    // guest_mode_test.dart, which tests this same page).
    await tester.pump(const Duration(milliseconds: 600));
  }

  const locale = Locale('en');
  String s(String key) => AppStrings.tr(locale, key);

  testWidgets('does not show Google or Apple sign-in buttons', (
    tester,
  ) async {
    await pumpWelcomePage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Sign in with Apple'), findsNothing);
  });

  testWidgets('the Email button is still present and opens SignInEmailPage', (
    tester,
  ) async {
    await pumpWelcomePage(tester);
    await tester.pumpAndSettle();

    final emailButton = find.text(s(AppStrings.signInEmail));
    expect(emailButton, findsOneWidget);

    await tester.tap(emailButton);
    await tester.pumpAndSettle();

    expect(find.byType(SignInEmailPage), findsOneWidget);
  });

  testWidgets('the Continue as Guest button is still present', (
    tester,
  ) async {
    await pumpWelcomePage(tester);
    await tester.pumpAndSettle();

    expect(find.text(s(AppStrings.continueAsGuest)), findsOneWidget);
  });
}
