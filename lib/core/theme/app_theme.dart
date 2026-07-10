import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui_theme.dart';

class AppTheme {
  static final lightTheme = _build(const UiTheme.light(), Brightness.light);
  static final darkTheme = _build(const UiTheme.dark(), Brightness.dark);

  static ThemeData _build(UiTheme uiTheme, Brightness brightness) {
    final colors = uiTheme.colors;
    final base = brightness == Brightness.light
        ? ColorScheme.light(
            primary: colors.primary,
            surface: colors.surface,
            onSurface: colors.primary,
            secondary: colors.secondary,
          )
        : ColorScheme.dark(
            primary: colors.primary,
            surface: colors.surface,
            onSurface: colors.primary,
            secondary: colors.secondary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.primary),
        titleTextStyle: GoogleFonts.inter(
          color: colors.primary,
          fontSize: uiTheme.typography.titleLarge.fontSize,
          fontWeight: uiTheme.typography.titleLarge.fontWeight,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(
        brightness == Brightness.light
            ? ThemeData.light().textTheme
            : ThemeData.dark().textTheme,
      ),
      dialogTheme: DialogThemeData(backgroundColor: colors.surface),
      dividerColor: colors.divider,
      extensions: [uiTheme],
    );
  }
}
