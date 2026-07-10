import 'package:flutter/material.dart';

/// Semantic color palette for one brightness. Values are ported 1:1 from the
/// pre-existing [AppTheme] statics — no new palette introduced.
class UiColors {
  const UiColors({
    required this.primary,
    required this.surface,
    required this.background,
    required this.secondary,
    required this.divider,
  });

  const UiColors.light()
      : primary = Colors.black,
        surface = Colors.white,
        background = const Color(0xFFF2F2F7),
        secondary = const Color(0xFFE5E5EA),
        divider = const Color(0xFFC6C6C8);

  const UiColors.dark()
      : primary = Colors.white,
        surface = const Color(0xFF2C2C2E),
        background = Colors.black,
        secondary = const Color(0xFF1C1C1E),
        divider = const Color(0xFF38383A);

  final Color primary;
  final Color surface;
  final Color background;
  final Color secondary;
  final Color divider;

  UiColors lerp(UiColors other, double t) {
    return UiColors(
      primary: Color.lerp(primary, other.primary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      background: Color.lerp(background, other.background, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiColors &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          surface == other.surface &&
          background == other.background &&
          secondary == other.secondary &&
          divider == other.divider;

  @override
  int get hashCode =>
      Object.hash(primary, surface, background, secondary, divider);
}
