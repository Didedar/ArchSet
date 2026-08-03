import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/theme/tokens/ui_typography.dart';

void main() {
  test(
    'titleLarge matches the existing AppBarTheme.titleTextStyle size/weight',
    () {
      const typography = UiTypography();

      expect(typography.titleLarge.fontSize, 17);
      expect(typography.titleLarge.fontWeight, FontWeight.w600);
    },
  );

  test('two default instances are equal', () {
    expect(const UiTypography(), const UiTypography());
  });
}
