import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/theme/tokens/ui_radius.dart';

void main() {
  test('exposes the named radius scale in ascending order', () {
    const radius = UiRadius();

    expect(radius.sm, 4);
    expect(radius.md, 12);
    expect(radius.lg, 16);
    expect(radius.xl, 20);
    expect(radius.pill, 30);
  });

  test('two default instances are equal', () {
    expect(const UiRadius(), const UiRadius());
  });
}
