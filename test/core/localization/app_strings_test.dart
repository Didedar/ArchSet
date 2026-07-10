import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/core/localization/app_strings.dart';

void main() {
  test('tr returns the localized value for the given locale', () {
    expect(AppStrings.tr(const Locale('ru'), AppStrings.cancel), 'Отмена');
  });

  test('tr falls back to English when the locale has no translations', () {
    expect(AppStrings.tr(const Locale('fr'), AppStrings.cancel), 'Cancel');
  });
}
