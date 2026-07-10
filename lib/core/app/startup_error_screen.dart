import 'package:flutter/material.dart';

/// Rendered when [CompositionRoot.initDependencies] fails. [onRetry]
/// re-runs the same composition closure, so a transient failure (e.g.
/// flaky storage) can recover without a process restart.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    required this.error,
    required this.stackTrace,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final StackTrace stackTrace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong starting the app'),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
