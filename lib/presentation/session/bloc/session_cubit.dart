import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/current_owner_holder.dart';
import '../../../data/services/auth_service.dart' show AuthUser;
import '../../../domain/repositories/auth_repository.dart';

/// Single source of truth for "who is using the app".
///
/// Routing decisions (e.g. sending guests straight to the offline diary and
/// only showing the login screen on explicit logout / lost session) are
/// driven off this state, not off [AuthRepository] directly.
sealed class AppSession extends Equatable {
  const AppSession();

  @override
  List<Object?> get props => const [];
}

/// Initial state before [SessionCubit.bootstrap] has resolved.
final class SessionUnknown extends AppSession {
  const SessionUnknown();
}

/// No authenticated user, but not logged out either -- the local-first
/// default. The diary stays reachable offline in this state.
final class SessionGuest extends AppSession {
  const SessionGuest();
}

final class SessionAuthenticated extends AppSession {
  const SessionAuthenticated(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// Explicit logout or a lost/expired session. Distinct from [SessionGuest]
/// so routing can show the login screen only here.
final class SessionUnauthenticated extends AppSession {
  const SessionUnauthenticated();
}

class SessionCubit extends Cubit<AppSession> {
  SessionCubit({
    required AuthRepository repository,
    CurrentOwnerHolder? ownerHolder,
    Stream<void>? sessionExpiredSignal,
  }) : _repository = repository,
       _ownerHolder = ownerHolder ?? CurrentOwnerHolder(),
       super(const SessionUnknown()) {
    _expiredSub = sessionExpiredSignal?.listen((_) => sessionLost());
  }

  final AuthRepository _repository;

  /// The account local data is currently scoped to. Shared via DI with
  /// [NotesRepository] so both stay in lockstep with auth state; kept in
  /// sync with every emitted [AppSession] by [_emit].
  final CurrentOwnerHolder _ownerHolder;
  StreamSubscription<void>? _expiredSub;

  /// Cold start. Never yields [SessionUnauthenticated]: a missing/dead
  /// stored session drops to [SessionGuest] so the local diary stays
  /// reachable offline.
  Future<void> bootstrap() async {
    try {
      final user = await _repository.loadStoredUser();
      _emit(user != null ? SessionAuthenticated(user) : const SessionGuest());
    } catch (_) {
      _emit(const SessionGuest());
    }
  }

  void loginSuccess(AuthUser user) => _emit(SessionAuthenticated(user));

  /// "Use the app without an account", chosen explicitly on the login screen.
  ///
  /// Lands on the same state a cold start with no stored user produces, so
  /// routing sends the user to the offline-first diary instead of holding
  /// them on [SessionUnauthenticated]'s login screen. Deliberately does not
  /// touch the repository: there is no session to clear, and a guest has no
  /// owner -- [_emit] resets the owner holder to null on the way through.
  void continueAsGuest() => _emit(const SessionGuest());

  Future<void> logout() async {
    await _repository.logout();
    _emit(const SessionUnauthenticated());
  }

  /// Permanently deletes the signed-in account and transitions to
  /// [SessionUnauthenticated] -- the same terminal state [logout] reaches,
  /// so routing needs no separate handling for it.
  ///
  /// Deliberately does not touch local diary data; unlike [logout], the
  /// caller (SettingsPage) wipes it separately, and only after this
  /// completes successfully. Propagates any failure from the repository
  /// instead of swallowing it, so the caller knows the account was NOT
  /// deleted and must not wipe anything.
  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    _emit(const SessionUnauthenticated());
  }

  void sessionLost() => _emit(const SessionUnauthenticated());

  /// Single choke point for every state transition: updates [_ownerHolder]
  /// before emitting, so anything reacting to the new [AppSession] (e.g. a
  /// repository read triggered by a rebuilt widget) already sees the right
  /// owner.
  void _emit(AppSession session) {
    _ownerHolder.value = session is SessionAuthenticated
        ? session.user.id
        : null;
    emit(session);
  }

  @override
  Future<void> close() async {
    await _expiredSub?.cancel();
    return super.close();
  }
}
