import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/pages/splash_page.dart';
import '../auth/pages/welcome_page.dart';
import '../notes/pages/notes_page.dart';
import 'bloc/session_cubit.dart';

/// Declarative root screen, driven entirely by [SessionCubit]'s [AppSession].
///
/// Replaces the old one-shot `AuthCheckRequested` navigation that used to
/// live in `SplashPage`: guests and authenticated users both land on the
/// (offline-first) diary, and only an explicit logout / lost session sends
/// the user to [WelcomePage].
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  /// The screen for a given [AppSession]. A pure function so routing can be
  /// tested without mounting a [SessionCubit] or a widget tree.
  @visibleForTesting
  static Widget screenFor(AppSession session) => switch (session) {
    SessionUnknown() => const SplashPage(),
    SessionGuest() || SessionAuthenticated() => const NotesPage(),
    SessionUnauthenticated() => const WelcomePage(),
  };

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SessionCubit, AppSession>(builder: (c, s) => screenFor(s));
}
