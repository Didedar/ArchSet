import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS Light Gray
    colorScheme: const ColorScheme.light(
      primary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      secondary: Color(0xFFE5E5EA),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF2F2F7),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      titleTextStyle: GoogleFonts.inter(
        color: Colors.black,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    dialogBackgroundColor: Colors.white,
    dividerColor: const Color(0xFFC6C6C8),
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      surface: Color(0xFF2C2C2E),
      onSurface: Colors.white,
      secondary: Color(0xFF1C1C1E),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    dialogBackgroundColor: const Color(0xFF2C2C2E),
    dividerColor: const Color(0xFF38383A),
  );
}
