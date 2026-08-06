import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/repositories/theme_repository.dart';

class SecureStorageThemeRepository implements ThemeRepository {
  const SecureStorageThemeRepository({required FlutterSecureStorage storage})
    : _storage = storage;

  static const _key = 'theme_mode';

  final FlutterSecureStorage _storage;

  @override
  Future<ThemeMode> loadThemeMode() async {
    final saved = await _storage.read(key: _key);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    await _storage.write(
      key: _key,
      value: mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
