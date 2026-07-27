import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/claim_service.dart';
import '../core_deps/core_dependencies.dart';
import '../sync/bloc/sync_bloc.dart';
import 'bloc/session_cubit.dart';
import 'guest_claim_coordinator.dart';

/// Mounts below the session + sync providers. On each transition into
/// [SessionAuthenticated], claims unclaimed local data for the account and
/// asks [SyncBloc] to push it.
class GuestClaimListener extends StatelessWidget {
  const GuestClaimListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionCubit, AppSession>(
      listenWhen: (previous, current) => current is SessionAuthenticated,
      listener: (context, state) {
        GuestClaimCoordinator(
          claimService: ClaimService(context.read<CoreDependencies>().database),
          syncBloc: context.read<SyncBloc>(),
        ).handleSession(state);
      },
      child: child,
    );
  }
}
