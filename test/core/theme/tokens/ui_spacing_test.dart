import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/theme/tokens/ui_spacing.dart';

void main() {
  test('exposes the named spacing scale in ascending order', () {
    const spacing = UiSpacing();

    expect(spacing.xs, 4);
    expect(spacing.sm, 8);
    expect(spacing.md, 16);
    expect(spacing.lg, 24);
    expect(spacing.xl, 32);
  });

  test('two default instances are equal', () {
    expect(const UiSpacing(), const UiSpacing());
  });
}
