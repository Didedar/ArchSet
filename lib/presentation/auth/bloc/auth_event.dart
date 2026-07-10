part of 'auth_bloc.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested(this.email, this.password);

  final String email;
  final String password;
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested(this.email, this.password);

  final String email;
  final String password;
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
