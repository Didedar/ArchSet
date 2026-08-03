import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:archset_r2/core/theme/app_theme.dart';
import 'package:archset_r2/presentation/widgets/empty_state.dart';

/// [EmptyState] used to hardcode `Color.fromRGBO(255, 255, 255, …)` for both
/// its lines. Against the light theme's near-white scaffold that is white on
/// white -- "No notes yet?" and "No folders yet" were rendered but invisible.
void main() {
  // AppTheme's themes are `static final` and build their text theme through
  // google_fonts. Resolving one outside a test zone makes google_fonts attempt
  // a live HTTP fetch and fail the whole file at load time, so themes are only
  // touched inside test bodies (below) and runtime fetching is off.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// WCAG relative luminance, used to assert the text is actually readable
  /// against the background rather than asserting an exact colour (which would
  /// just restate the implementation).
  double luminance(Color c) => c.computeLuminance();

  double contrastRatio(Color fg, Color bg) {
    final l1 = luminance(fg);
    final l2 = luminance(bg);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Flattens a possibly-translucent foreground over its background, since the
  /// widget draws its text at partial alpha.
  Color composite(Color fg, Color bg) => Color.alphaBlend(fg, bg);

  Future<List<Text>> pumpAndCollect(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.folder_outlined,
            title: 'No folders yet',
            subtitle: 'Tap + to create your first folder',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widgetList<Text>(find.byType(Text)).toList();
  }

  for (final (name, themeOf) in <(String, ThemeData Function())>[
    ('light', () => AppTheme.lightTheme),
    ('dark', () => AppTheme.darkTheme),
  ]) {
    testWidgets('$name theme: both lines are readable against the scaffold', (
      tester,
    ) async {
      final theme = themeOf();
      final texts = await pumpAndCollect(tester, theme);
      final background = theme.scaffoldBackgroundColor;

      expect(texts, hasLength(2), reason: 'title + subtitle');

      for (final text in texts) {
        final color = text.style?.color;
        expect(color, isNotNull, reason: '"${text.data}" has no colour');

        final ratio = contrastRatio(composite(color!, background), background);
        expect(
          ratio,
          greaterThan(3.0),
          reason:
              '"${text.data}" has contrast ${ratio.toStringAsFixed(2)}:1 '
              'against the $name scaffold -- effectively invisible',
        );
      }
    });
  }

  testWidgets('the title colour tracks the theme instead of being fixed', (
    tester,
  ) async {
    final light = await pumpAndCollect(tester, AppTheme.lightTheme);
    final dark = await pumpAndCollect(tester, AppTheme.darkTheme);

    expect(
      light.first.style?.color,
      isNot(dark.first.style?.color),
      reason: 'a hardcoded colour would be identical in both themes',
    );
  });
}
