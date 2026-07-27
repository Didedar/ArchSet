import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    Stream<void>? sessionExpiredSignal,
  })  : _repository = repository,
        super(const SessionUnknown()) {
    _expiredSub = sessionExpiredSignal?.listen((_) => sessionLost());
  }

  final AuthRepository _repository;
  StreamSubscription<void>? _expiredSub;

  /// Cold start. Never yields [SessionUnauthenticated]: a missing/dead
  /// stored session drops to [SessionGuest] so the local diary stays
  /// reachable offline.
  Future<void> bootstrap() async {
    try {
      final user = await _repository.loadStoredUser();
      emit(user != null ? SessionAuthenticated(user) : const SessionGuest());
    } catch (_) {
      emit(const SessionGuest());
    }
  }

  void loginSuccess(AuthUser user) => emit(SessionAuthenticated(user));

  Future<void> logout() async {
    await _repository.logout();
    emit(const SessionUnauthenticated());
  }

  void sessionLost() => emit(const SessionUnauthenticated());

  @override
  Future<void> close() async {
    await _expiredSub?.cancel();
    return super.close();
  }
}
