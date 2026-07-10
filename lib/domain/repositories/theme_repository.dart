import 'package:flutter/material.dart';

abstract interface class ThemeRepository {
  Future<ThemeMode> loadThemeMode();
  Future<void> saveThemeMode(ThemeMode mode);
}
