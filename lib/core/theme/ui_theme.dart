import 'package:flutter/material.dart';
import 'tokens/ui_colors.dart';
import 'tokens/ui_radius.dart';
import 'tokens/ui_spacing.dart';
import 'tokens/ui_typography.dart';

/// Aggregates the app's design tokens into a single [ThemeExtension] so
/// every token group flows through the same `ThemeData.extensions` pipeline
/// (and so `ThemeData` transitions interpolate colors via [lerp]).
class UiTheme extends ThemeExtension<UiTheme> {
  const UiTheme({
    required this.colors,
    this.spacing = const UiSpacing(),
    this.typography = const UiTypography(),
    this.radius = const UiRadius(),
  });

  const UiTheme.light() : this(colors: const UiColors.light());

  const UiTheme.dark() : this(colors: const UiColors.dark());

  final UiColors colors;
  final UiSpacing spacing;
  final UiTypography typography;
  final UiRadius radius;

  /// Falls back to [UiTheme.light] if no extension is registered, so
  /// widgets never crash on a misconfigured [MaterialApp].
  static UiTheme of(BuildContext context) =>
      Theme.of(context).extension<UiTheme>() ?? const UiTheme.light();

  @override
  UiTheme copyWith({
    UiColors? colors,
    UiSpacing? spacing,
    UiTypography? typography,
    UiRadius? radius,
  }) {
    return UiTheme(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      typography: typography ?? this.typography,
      radius: radius ?? this.radius,
    );
  }

  @override
  UiTheme lerp(ThemeExtension<UiTheme>? other, double t) {
    if (other is! UiTheme) return this;
    return UiTheme(
      colors: colors.lerp(other.colors, t),
      spacing: t < 0.5 ? spacing : other.spacing,
      typography: t < 0.5 ? typography : other.typography,
      radius: t < 0.5 ? radius : other.radius,
    );
  }
}
