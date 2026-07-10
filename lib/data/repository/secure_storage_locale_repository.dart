import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/repositories/locale_repository.dart';

class SecureStorageLocaleRepository implements LocaleRepository {
  const SecureStorageLocaleRepository({required FlutterSecureStorage storage})
      : _storage = storage;

  static const _key = 'language_code';

  final FlutterSecureStorage _storage;

  @override
  Future<Locale> loadLocale() async {
    final saved = await _storage.read(key: _key);
    return Locale(saved ?? 'en');
  }

  @override
  Future<void> saveLocale(String languageCode) async {
    await _storage.write(key: _key, value: languageCode);
  }
}
