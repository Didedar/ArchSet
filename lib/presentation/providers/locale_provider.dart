import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  final _storage = const FlutterSecureStorage();
  static const _key = 'language_code';

  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final savedCode = await _storage.read(key: _key);
    if (savedCode != null) {
      state = Locale(savedCode);
    }
  }

  Future<void> setLocale(String languageCode) async {
    state = Locale(languageCode);
    await _storage.write(key: _key, value: languageCode);
  }
}
