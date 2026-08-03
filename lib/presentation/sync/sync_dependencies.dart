import '../../data/services/members_service.dart';
import '../../data/services/sync_service.dart';

class SyncDependencies {
  const SyncDependencies({required this.service, required this.members});

  final SyncService service;

  /// Dig-site membership. Lives here rather than in its own container
  /// because it shares the one [ApiService] this builder constructs -- and
  /// with it the token refresh that every authenticated call depends on.
  final MembersService members;
}
