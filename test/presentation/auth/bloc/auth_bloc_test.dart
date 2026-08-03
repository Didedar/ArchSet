import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/domain/repositories/auth_repository.dart';
import 'package:archset_r2/presentation/auth/bloc/auth_bloc.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  final user = AuthUser(id: '1', email: 'a@b.com', createdAt: DateTime(2026));

  setUp(() {
    repository = _MockAuthRepository();
  });

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits Authenticated when a stored user exists',
      setUp: () =>
          when(() => repository.loadStoredUser()).thenAnswer((_) async => user),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), AuthAuthenticated(user)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated when no stored user exists',
      setUp: () =>
          when(() => repository.loadStoredUser()).thenAnswer((_) async => null),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated (not stuck) when loadStoredUser throws',
      setUp: () => when(
        () => repository.loadStoredUser(),
      ).thenThrow(Exception('network error')),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
    );
  });

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits Authenticated on successful login',
      setUp: () => when(
        () => repository.login('a@b.com', 'pw'),
      ).thenAnswer((_) async => user),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthLoginRequested('a@b.com', 'pw')),
      expect: () => [const AuthLoading(), AuthAuthenticated(user)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Failure with the error message on failed login',
      setUp: () => when(
        () => repository.login('a@b.com', 'wrong'),
      ).thenThrow(Exception('Invalid credentials')),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthLoginRequested('a@b.com', 'wrong')),
      expect: () => [
        const AuthLoading(),
        const AuthFailure('Exception: Invalid credentials'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'drops a second login while one is in flight',
      setUp: () =>
          when(() => repository.login(any(), any())).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return user;
          }),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc
        ..add(const AuthLoginRequested('a@b.com', 'pw'))
        ..add(const AuthLoginRequested('a@b.com', 'pw')),
      wait: const Duration(milliseconds: 50),
      expect: () => [const AuthLoading(), AuthAuthenticated(user)],
      verify: (_) {
        verify(() => repository.login('a@b.com', 'pw')).called(1);
      },
    );
  });

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'registers then logs in to establish a session, emitting Authenticated',
      setUp: () {
        when(
          () => repository.register('a@b.com', 'pw'),
        ).thenAnswer((_) async => user);
        when(
          () => repository.login('a@b.com', 'pw'),
        ).thenAnswer((_) async => user);
      },
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthRegisterRequested('a@b.com', 'pw')),
      expect: () => [const AuthLoading(), AuthAuthenticated(user)],
      verify: (_) {
        // register() alone doesn't store session tokens -- login() must
        // follow, or the "authenticated" user has no actual session.
        verify(() => repository.register('a@b.com', 'pw')).called(1);
        verify(() => repository.login('a@b.com', 'pw')).called(1);
      },
    );
  });

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated after logout',
      setUp: () => when(() => repository.logout()).thenAnswer((_) async {}),
      build: () => AuthBloc(repository: repository),
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [const AuthUnauthenticated()],
      verify: (_) {
        verify(() => repository.logout()).called(1);
      },
    );
  });

  test('initial state is AuthInitial', () {
    expect(AuthBloc(repository: repository).state, const AuthInitial());
  });
}
