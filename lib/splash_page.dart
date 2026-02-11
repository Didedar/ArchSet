import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'notes.dart';
import 'welcome_page.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/sync_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    super.initState();
    // Use addPostFrameCallback to ensure context is available if needed,
    // though for _checkAuth logic (async), calling it directly is also fine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    // Add a small delay to show the splash screen (optional, but looks nicer)
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.loadStoredUser();

      if (!mounted) return;

      if (user != null) {
        // User is logged in, sync data and go to notes
        try {
          // We don't await sync here to not block the UI,
          // but we start it so data is fresh
          ref.read(syncServiceProvider).sync();
        } catch (e) {
          debugPrint('Sync failed on startup: $e');
        }

        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const NotesPage()),
        );
      } else {
        // User is not logged in, go to welcome page
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    } catch (e) {
      debugPrint('Auth check failed: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const WelcomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo or Icon
            Image.asset(
              'assets/images/icon_email.png', // Using existing asset as placeholder if main logo not available
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
