import 'package:flutter/material.dart';

/// Purely visual splash screen, shown while `SessionCubit` resolves the
/// stored session (`AppSession.SessionUnknown`, via `SessionGate`).
///
/// Session resolution used to be a one-shot `AuthCheckRequested` dispatched
/// from here, with navigation driven by the resulting `AuthState`. That
/// logic now lives in `AppScope` (`SessionCubit..bootstrap()`), and routing
/// is driven declaratively by `SessionGate` -- this widget has nothing left
/// to do but render.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/icon_email.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFFFF9F0A)),
          ],
        ),
      ),
    );
  }
}
