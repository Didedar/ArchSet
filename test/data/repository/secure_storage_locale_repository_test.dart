import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archset_r2/data/repository/secure_storage_locale_repository.dart';
import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installFakeSecureStorage);

  test('loadLocale defaults to English when nothing is stored', () async {
    final repository = SecureStorageLocaleRepository(
      storage: const FlutterSecureStorage(),
    );

    expect(await repository.loadLocale(), const Locale('en'));
  });

  test('saveLocale persists a value loadLocale later returns', () async {
    final repository = SecureStorageLocaleRepository(
      storage: const FlutterSecureStorage(),
    );

    await repository.saveLocale('ru');

    expect(await repository.loadLocale(), const Locale('ru'));
  });
}
