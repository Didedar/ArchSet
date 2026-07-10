import '../../data/services/auth_service.dart';

/// Holds the concrete [AuthService] (not just the [AuthRepository]
/// interface) -- AuthBloc only needs the interface, but SyncDependencies
/// (Phase 3) needs AuthService's token methods (getAccessToken,
/// refreshAccessToken) to build an ApiService, which aren't part of that
/// interface.
class AuthDependencies {
  const AuthDependencies({required this.repository});

  final AuthService repository;
}
