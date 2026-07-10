import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../notes.dart';
import '../bloc/auth_bloc.dart';
import '../../sync/bloc/sync_bloc.dart';
import 'welcome_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
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
        context.read<SyncBloc>().add(const SyncRequested());
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
