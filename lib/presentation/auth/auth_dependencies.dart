import '../../domain/repositories/auth_repository.dart';

class AuthDependencies {
  const AuthDependencies({required this.repository});

  final AuthRepository repository;
}
