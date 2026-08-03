import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/app/startup_error_screen.dart';

void main() {
  testWidgets('shows the error message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupErrorScreen(
          error: Exception('database locked'),
          stackTrace: StackTrace.current,
          onRetry: () {},
        ),
      ),
    );

    expect(find.textContaining('database locked'), findsOneWidget);
  });

  testWidgets('tapping retry invokes the callback', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupErrorScreen(
          error: Exception('boom'),
          stackTrace: StackTrace.current,
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.tap(find.text('Retry'));

    expect(retried, isTrue);
  });
}
