import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notes.dart';
import '../../providers/sync_provider.dart';
import '../bloc/auth_bloc.dart';
import 'welcome_page.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    // Small delay to show the splash screen (kept from the pre-migration
    // behavior, purely cosmetic).
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    context.read<AuthBloc>().add(const AuthCheckRequested());
  }

  void _onAuthStateChanged(BuildContext context, AuthState state) {
    switch (state) {
      case AuthAuthenticated():
        // Fire-and-forget: don't block navigation on sync completing.
        // Sync stays on Riverpod until Phase 3.
        try {
          ref.read(syncServiceProvider).sync();
        } catch (e) {
          debugPrint('Sync failed on startup: $e');
        }
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const NotesPage()),
        );
      case AuthUnauthenticated():
      case AuthFailure():
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const WelcomePage()),
        );
      case AuthInitial():
      case AuthLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _onAuthStateChanged,
      child: Scaffold(
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
      ),
    );
  }
}
