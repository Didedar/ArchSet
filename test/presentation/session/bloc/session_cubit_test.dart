import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archset_r2/data/current_owner_holder.dart';
import 'package:archset_r2/data/services/auth_service.dart';
import 'package:archset_r2/domain/repositories/auth_repository.dart';
import 'package:archset_r2/presentation/session/bloc/session_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  final user = AuthUser(id: '1', email: 'a@b.com', createdAt: DateTime(2026));

  setUp(() {
    repository = _MockAuthRepository();
  });

  test('initial state is SessionUnknown', () {
    expect(SessionCubit(repository: repository).state, const SessionUnknown());
  });

  group('bootstrap', () {
    blocTest<SessionCubit, AppSession>(
      'emits SessionAuthenticated when a stored user exists',
      setUp: () => when(() => repository.loadStoredUser())
          .thenAnswer((_) async => user),
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.bootstrap(),
      expect: () => [SessionAuthenticated(user)],
    );

    blocTest<SessionCubit, AppSession>(
      'emits SessionGuest when no stored user exists',
      setUp: () => when(() => repository.loadStoredUser())
          .thenAnswer((_) async => null),
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.bootstrap(),
      expect: () => [const SessionGuest()],
    );

    blocTest<SessionCubit, AppSession>(
      'emits SessionGuest (not stuck, not Unauthenticated) when '
      'loadStoredUser throws',
      setUp: () => when(() => repository.loadStoredUser())
          .thenThrow(Exception('network error')),
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.bootstrap(),
      expect: () => [const SessionGuest()],
    );
  });

  group('loginSuccess', () {
    blocTest<SessionCubit, AppSession>(
      'emits SessionAuthenticated with the given user',
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.loginSuccess(user),
      expect: () => [SessionAuthenticated(user)],
    );
  });

  group('logout', () {
    blocTest<SessionCubit, AppSession>(
      'emits SessionUnauthenticated and calls repository.logout()',
      setUp: () => when(() => repository.logout()).thenAnswer((_) async {}),
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.logout(),
      expect: () => [const SessionUnauthenticated()],
      verify: (_) {
        verify(() => repository.logout()).called(1);
      },
    );
  });

  group('sessionLost', () {
    blocTest<SessionCubit, AppSession>(
      'emits SessionUnauthenticated',
      build: () => SessionCubit(repository: repository),
      act: (cubit) => cubit.sessionLost(),
      expect: () => [const SessionUnauthenticated()],
    );
  });

  group('sessionExpiredSignal', () {
    test(
      'an event pushed on the signal stream drives SessionUnauthenticated',
      () async {
        final controller = StreamController<void>();
        final cubit = SessionCubit(
          repository: repository,
          sessionExpiredSignal: controller.stream,
        );
        final states = <AppSession>[];
        final sub = cubit.stream.listen(states.add);

        controller.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(states, [const SessionUnauthenticated()]);

        await sub.cancel();
        await controller.close();
        await cubit.close();
      },
    );

    test('cancels the sessionExpiredSignal subscription on close', () async {
      final controller = StreamController<void>();
      final cubit = SessionCubit(
        repository: repository,
        sessionExpiredSignal: controller.stream,
      );

      expect(controller.hasListener, isTrue);

      await cubit.close();

      expect(controller.hasListener, isFalse);

      await controller.close();
    });
  });

  /// Closes a cross-account data leak: [NotesRepository] shares this same
  /// [CurrentOwnerHolder] instance (via DI) to stamp writes and scope reads,
  /// so it must track every session transition, not just login.
  group('ownerHolder', () {
    late CurrentOwnerHolder holder;

    setUp(() {
      holder = CurrentOwnerHolder();
    });

    blocTest<SessionCubit, AppSession>(
      'becomes user.id when bootstrap resolves an authenticated session',
      setUp: () => when(() => repository.loadStoredUser())
          .thenAnswer((_) async => user),
      build: () => SessionCubit(repository: repository, ownerHolder: holder),
      act: (cubit) => cubit.bootstrap(),
      verify: (_) => expect(holder.value, user.id),
    );

    blocTest<SessionCubit, AppSession>(
      'stays null when bootstrap resolves a guest session',
      setUp: () => when(() => repository.loadStoredUser())
          .thenAnswer((_) async => null),
      build: () => SessionCubit(repository: repository, ownerHolder: holder),
      act: (cubit) => cubit.bootstrap(),
      verify: (_) => expect(holder.value, isNull),
    );

    blocTest<SessionCubit, AppSession>(
      'becomes user.id on loginSuccess',
      build: () => SessionCubit(repository: repository, ownerHolder: holder),
      act: (cubit) => cubit.loginSuccess(user),
      verify: (_) => expect(holder.value, user.id),
    );

    blocTest<SessionCubit, AppSession>(
      'reverts to null on logout after being set by loginSuccess',
      setUp: () => when(() => repository.logout()).thenAnswer((_) async {}),
      build: () => SessionCubit(repository: repository, ownerHolder: holder),
      act: (cubit) async {
        cubit.loginSuccess(user);
        await cubit.logout();
      },
      verify: (_) => expect(holder.value, isNull),
    );

    blocTest<SessionCubit, AppSession>(
      'reverts to null on sessionLost after being set by loginSuccess',
      build: () => SessionCubit(repository: repository, ownerHolder: holder),
      act: (cubit) {
        cubit.loginSuccess(user);
        cubit.sessionLost();
      },
      verify: (_) => expect(holder.value, isNull),
    );
  });
}
