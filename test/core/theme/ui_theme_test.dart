import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/theme/tokens/ui_colors.dart';
import 'package:archset_r2/core/theme/ui_theme.dart';

void main() {
  test('UiTheme.light bundles the light color palette', () {
    expect(const UiTheme.light().colors, const UiColors.light());
  });

  test('UiTheme.dark bundles the dark color palette', () {
    expect(const UiTheme.dark().colors, const UiColors.dark());
  });

  test('lerp at t=0 keeps this instance\'s colors, t=1 takes the other\'s', () {
    const light = UiTheme.light();
    const dark = UiTheme.dark();

    expect(light.lerp(dark, 0).colors, light.colors);
    expect(light.lerp(dark, 1).colors, dark.colors);
  });

  testWidgets('UiTheme.of falls back to light when no extension is registered',
      (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox();
        },
      ),
    ));

    expect(UiTheme.of(capturedContext).colors, const UiColors.light());
  });
}
