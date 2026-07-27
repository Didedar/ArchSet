import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archset_r2/core/app/root_context.dart';
import 'package:archset_r2/presentation/auth/pages/welcome_page.dart';
import 'package:archset_r2/presentation/locale/bloc/locale_bloc.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';
import 'package:archset_r2/presentation/theme/bloc/theme_bloc.dart';

class _MockSessionCubit extends MockCubit<AppSession> implements SessionCubit {}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState>
    implements ThemeBloc {}

class _MockLocaleBloc extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

void main() {
  late _MockSessionCubit sessionCubit;
  late _MockThemeBloc themeBloc;
  late _MockLocaleBloc localeBloc;
  late StreamController<AppSession> sessionController;

  setUp(() {
    sessionController = StreamController<AppSession>.broadcast();
    sessionCubit = _MockSessionCubit();
    whenListen(
      sessionCubit,
      sessionController.stream,
      initialState: const SessionUnknown(),
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
  });

  tearDown(() {
    sessionController.close();
  });

  Future<void> pumpRootContext(WidgetTester tester) {
    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionCubit>.value(value: sessionCubit),
          BlocProvider<ThemeBloc>.value(value: themeBloc),
          BlocProvider<LocaleBloc>.value(value: localeBloc),
        ],
        child: const RootContext(),
      ),
    );
  }

  testWidgets('resets navigation to the root screen when the session becomes '
      'Unauthenticated -- and never touches SyncBloc while doing it (no '
      'SyncBloc is provided in this tree at all: if the listener tried to '
      'read one it would throw ProviderNotFoundException instead of quietly '
      'passing)', (tester) async {
    await pumpRootContext(tester);

    // Simulate a screen the user had navigated to while guest/authenticated.
    rootNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('PUSHED_MARKER')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PUSHED_MARKER'), findsOneWidget);

    // Session is lost: explicit logout, or an expired/rejected token.
    sessionController.add(const SessionUnauthenticated());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PUSHED_MARKER'), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);

    // WelcomePage schedules a delayed intro-animation timer in initState;
    // drain it so the test doesn't finish with a pending fake timer.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 1300));
  });
}
