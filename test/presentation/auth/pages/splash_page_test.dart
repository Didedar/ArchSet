import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/auth/pages/splash_page.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: const AuthInitial());
  });

  testWidgets('shows the splash UI and dispatches AuthCheckRequested',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const SplashPage(),
        ),
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The auth check is deliberately delayed 500ms to let the splash show.
    await tester.pump(const Duration(milliseconds: 600));

    verify(() => authBloc.add(const AuthCheckRequested())).called(1);
  });
}
