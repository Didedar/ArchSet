import 'package:flutter/material.dart';

/// Named text styles. Deliberately holds plain size/weight data with no
/// [fontFamily] set — the Inter family is applied once, at the [ThemeData]
/// level, by `AppTheme` (via `GoogleFonts.interTextTheme`), the same way it
/// is today. Keeping font-loading out of this class keeps it a trivial,
/// side-effect-free value object.
class UiTypography {
  const UiTypography({
    this.titleLarge = const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  });

  final TextStyle titleLarge;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiTypography &&
          runtimeType == other.runtimeType &&
          titleLarge == other.titleLarge;

  @override
  int get hashCode => titleLarge.hashCode;
}
