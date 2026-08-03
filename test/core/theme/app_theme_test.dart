import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/theme/app_theme.dart';
import 'package:archset_r2/core/theme/ui_theme.dart';

void main() {
  Future<ThemeData> pumpAndReadTheme(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    late ThemeData resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            resolved = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return resolved;
  }

  group('AppTheme.lightTheme', () {
    testWidgets('preserves the existing color scheme', (tester) async {
      final theme = await pumpAndReadTheme(tester, AppTheme.lightTheme);

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF2F2F7));
      expect(theme.colorScheme.primary, Colors.black);
      expect(theme.colorScheme.surface, Colors.white);
      expect(theme.colorScheme.secondary, const Color(0xFFE5E5EA));
      expect(theme.dividerColor, const Color(0xFFC6C6C8));
      expect(theme.dialogTheme.backgroundColor, Colors.white);
    });

    testWidgets('preserves the existing app bar title style', (tester) async {
      final theme = await pumpAndReadTheme(tester, AppTheme.lightTheme);

      expect(theme.appBarTheme.titleTextStyle?.fontSize, 17);
      expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w600);
    });

    testWidgets('registers a UiTheme extension matching the light palette', (
      tester,
    ) async {
      final theme = await pumpAndReadTheme(tester, AppTheme.lightTheme);

      final uiTheme = theme.extension<UiTheme>();
      expect(uiTheme, isNotNull);
      expect(uiTheme!.colors, const UiTheme.light().colors);
    });
  });

  group('AppTheme.darkTheme', () {
    testWidgets('preserves the existing color scheme', (tester) async {
      final theme = await pumpAndReadTheme(tester, AppTheme.darkTheme);

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.colorScheme.primary, Colors.white);
      expect(theme.colorScheme.surface, const Color(0xFF2C2C2E));
      expect(theme.colorScheme.secondary, const Color(0xFF1C1C1E));
      expect(theme.dividerColor, const Color(0xFF38383A));
      expect(theme.dialogTheme.backgroundColor, const Color(0xFF2C2C2E));
    });

    testWidgets('registers a UiTheme extension matching the dark palette', (
      tester,
    ) async {
      final theme = await pumpAndReadTheme(tester, AppTheme.darkTheme);

      final uiTheme = theme.extension<UiTheme>();
      expect(uiTheme, isNotNull);
      expect(uiTheme!.colors, const UiTheme.dark().colors);
    });
  });
}
