import '../../data/services/claim_service.dart';
import '../sync/bloc/sync_bloc.dart';
import 'bloc/session_cubit.dart';

/// On a transition into [SessionAuthenticated], hands all unclaimed local rows
/// to the account and asks [SyncBloc] to push them. Guest/unauthenticated are
/// ignored. The account id comes from the authenticated session's user (equal
/// to the current_owner_id the auth layer persisted just before this).
class GuestClaimCoordinator {
  GuestClaimCoordinator({
    required ClaimService claimService,
    required SyncBloc syncBloc,
  }) : _claimService = claimService,
       _syncBloc = syncBloc;

  final ClaimService _claimService;
  final SyncBloc _syncBloc;

  Future<void> handleSession(AppSession session) async {
    if (session is! SessionAuthenticated) return;
    await _claimService.claimGuestData(session.user.id);
    _syncBloc.add(const SyncRequested());
  }
}
