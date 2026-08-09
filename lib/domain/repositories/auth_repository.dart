import '../../data/services/auth_service.dart' show AuthUser;

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Future<AuthUser> login(String email, String password);
  Future<AuthUser> register(String email, String password);
  Future<void> logout();
  Future<void> deleteAccount();
  Future<AuthUser?> loadStoredUser();
}
