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

  /// `tr` silently falls back to English for a missing key, so an untranslated
  /// string ships as an English word in a Russian UI rather than as a failure.
  /// These checks make a forgotten translation a red test instead.
  group('locale parity', () {
    for (final languageCode in AppStrings.supportedLanguageCodes) {
      test('$languageCode translates every declared key', () {
        final missing = [
          for (final key in AppStrings.allKeys)
            if (AppStrings.rawValue(languageCode, key) == null) key,
        ];

        expect(
          missing,
          isEmpty,
          reason:
              'Locale "$languageCode" is missing ${missing.length} '
              'translation(s): ${missing.join(', ')}',
        );
      });

      test('$languageCode has no blank translations', () {
        final blank = [
          for (final key in AppStrings.allKeys)
            if (AppStrings.rawValue(languageCode, key)?.trim() == '') key,
        ];

        expect(blank, isEmpty, reason: 'Blank in "$languageCode": $blank');
      });
    }

    test('the guest-mode strings are actually translated, not copied from '
        'English', () {
      // Sanity check on the keys added for guest mode: a copy-paste that left
      // the English text in the ru/kk/zh tables would pass the parity checks
      // above but ship an English-only guest flow.
      for (final key in [
        AppStrings.continueAsGuest,
        AppStrings.guestMode,
        AppStrings.noAccount,
        AppStrings.guestModeDescription,
        AppStrings.signInOrCreateAccount,
        AppStrings.signedIn,
      ]) {
        final english = AppStrings.rawValue('en', key);
        for (final languageCode in ['ru', 'kk', 'zh']) {
          expect(
            AppStrings.rawValue(languageCode, key),
            isNot(english),
            reason: '"$key" is untranslated in "$languageCode"',
          );
        }
      }
    });
  });
}
