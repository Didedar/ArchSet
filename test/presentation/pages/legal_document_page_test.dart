import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/presentation/pages/legal_document_page.dart';

void main() {
  testWidgets('renders the given title in the app bar and the body text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentPage(
          title: 'Privacy Policy',
          body: 'This is the policy body.',
        ),
      ),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('This is the policy body.'), findsOneWidget);
  });

  testWidgets('is pushable and popped by the back button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LegalDocumentPage(
                  title: 'Terms of Use',
                  body: 'Terms body.',
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
