import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/auth_service.dart' show AuthUser;
import '../../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository})
      : _repository = repository,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested, transformer: droppable());
    on<AuthLoginRequested>(_onLoginRequested, transformer: droppable());
    on<AuthRegisterRequested>(_onRegisterRequested, transformer: droppable());
    on<AuthLogoutRequested>(_onLogoutRequested, transformer: droppable());
  }

  final AuthRepository _repository;

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repository.loadStoredUser();
      emit(
        user != null ? AuthAuthenticated(user) : const AuthUnauthenticated(),
      );
    } catch (_) {
      // Matches the pre-migration SplashPage behavior: any failure to
      // check stored auth (e.g. offline) is treated as logged-out rather
      // than surfaced as an error, so the user isn't stuck on the splash
      // screen.
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repository.login(event.email, event.password);
      emit(AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // register() alone doesn't store session tokens -- login() must
      // follow immediately, or the new account has no active session.
      await _repository.register(event.email, event.password);
      final user = await _repository.login(event.email, event.password);
      emit(AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }
}
