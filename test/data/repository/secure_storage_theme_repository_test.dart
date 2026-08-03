import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/data/repository/secure_storage_theme_repository.dart';
import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  test('loadThemeMode defaults to system when nothing is stored', () async {
    final repository = SecureStorageThemeRepository(
      storage: const FlutterSecureStorage(),
    );

    expect(await repository.loadThemeMode(), ThemeMode.system);
  });

  test('saveThemeMode persists a value loadThemeMode later returns', () async {
    final repository = SecureStorageThemeRepository(
      storage: const FlutterSecureStorage(),
    );

    await repository.saveThemeMode(ThemeMode.dark);

    expect(await repository.loadThemeMode(), ThemeMode.dark);
  });

  test('loadThemeMode reads light mode correctly', () async {
    final repository = SecureStorageThemeRepository(
      storage: const FlutterSecureStorage(),
    );

    await repository.saveThemeMode(ThemeMode.light);

    expect(await repository.loadThemeMode(), ThemeMode.light);
  });
}
