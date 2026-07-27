import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/presentation/auth/pages/splash_page.dart';

void main() {
  testWidgets('renders the splash spinner with no bloc dependencies', (
    tester,
  ) async {
    // No BlocProvider of any kind above it: SplashPage is now pure UI.
    // Session resolution happens once in AppScope (SessionCubit..bootstrap),
    // not here.
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
