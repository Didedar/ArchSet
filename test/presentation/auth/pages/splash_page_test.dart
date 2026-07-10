import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';
import 'package:archset_r2/presentation/auth/pages/splash_page.dart';
import 'package:archset_r2/presentation/sync/bloc/sync_bloc.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockSyncBloc extends MockBloc<SyncEvent, SyncState> implements SyncBloc {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockSyncBloc syncBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: const AuthInitial());
    syncBloc = _MockSyncBloc();
    whenListen(syncBloc, const Stream<SyncState>.empty(),
        initialState: const SyncIdle());
  });

  testWidgets('shows the splash UI and dispatches AuthCheckRequested',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<SyncBloc>.value(value: syncBloc),
        ],
        child: const SplashPage(),
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The auth check is deliberately delayed 500ms to let the splash show.
    await tester.pump(const Duration(milliseconds: 600));

    verify(() => authBloc.add(const AuthCheckRequested())).called(1);
  });
}
