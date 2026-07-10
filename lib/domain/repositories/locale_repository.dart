import 'package:flutter/material.dart';

abstract interface class LocaleRepository {
  Future<Locale> loadLocale();
  Future<void> saveLocale(String languageCode);
}
