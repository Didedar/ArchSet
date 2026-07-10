import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/theme/tokens/ui_colors.dart';

void main() {
  test('light palette matches the existing AppTheme.lightTheme values', () {
    const colors = UiColors.light();

    expect(colors.primary, Colors.black);
    expect(colors.surface, Colors.white);
    expect(colors.background, const Color(0xFFF2F2F7));
    expect(colors.secondary, const Color(0xFFE5E5EA));
    expect(colors.divider, const Color(0xFFC6C6C8));
  });

  test('dark palette matches the existing AppTheme.darkTheme values', () {
    const colors = UiColors.dark();

    expect(colors.primary, Colors.white);
    expect(colors.surface, const Color(0xFF2C2C2E));
    expect(colors.background, Colors.black);
    expect(colors.secondary, const Color(0xFF1C1C1E));
    expect(colors.divider, const Color(0xFF38383A));
  });

  test('lerp at t=0 returns the start colors, t=1 returns the end colors', () {
    const light = UiColors.light();
    const dark = UiColors.dark();

    expect(light.lerp(dark, 0), light);
    expect(light.lerp(dark, 1), dark);
  });
}
