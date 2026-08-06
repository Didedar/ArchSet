import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:archset_r2/data/services/api_service.dart';
import 'package:archset_r2/data/services/backend_gemini_service.dart';

class _MockApiService extends Mock implements ApiService {}

class _FakeFile extends Fake implements File {}

/// Which language a photographed find is described in.
///
/// The prompt used to hardcode Russian, so an archaeologist keeping their
/// diary in Kazakh or Chinese got their own photo described back to them in a
/// language they had not chosen. The locale now travels with the upload.
void main() {
  setUpAll(() => registerFallbackValue(_FakeFile()));

  late _MockApiService api;
  late BackendGeminiService service;
  late Directory temp;
  late String imagePath;

  setUp(() async {
    api = _MockApiService();
    service = BackendGeminiService(apiService: api);
    temp = await Directory.systemTemp.createTemp('analyze_lang');
    imagePath = '${temp.path}/find.jpg';
    await File(imagePath).writeAsBytes([0xFF, 0xD8]);

    when(
      () => api.uploadFile(
        any(),
        any(),
        fieldName: any(named: 'fieldName'),
        fields: any(named: 'fields'),
      ),
    ).thenAnswer((_) async => {'success': true, 'analysis': '{}'});
  });

  tearDown(() => temp.delete(recursive: true));

  Map<String, String>? capturedFields() {
    final call = verify(
      () => api.uploadFile(
        any(),
        any(),
        fieldName: any(named: 'fieldName'),
        fields: captureAny(named: 'fields'),
      ),
    ).captured.single;
    return call as Map<String, String>?;
  }

  test('the chosen language travels with the photo', () async {
    await service.analyzeImage(imagePath, languageCode: 'kk');

    expect(capturedFields()?['language'], 'kk');
  });

  test('coordinates still travel alongside it', () async {
    await service.analyzeImage(
      imagePath,
      latitude: 43.2,
      longitude: 76.9,
      languageCode: 'zh',
    );

    final fields = capturedFields();
    expect(fields?['language'], 'zh');
    expect(fields?['latitude'], '43.2');
    expect(fields?['longitude'], '76.9');
  });

  test('no language means the field is simply absent', () async {
    // The backend defaults to English rather than guessing, so sending an
    // empty value would be worse than sending nothing.
    await service.analyzeImage(imagePath);

    expect(capturedFields()?.containsKey('language'), isFalse);
  });

  test('an empty language is treated as none', () async {
    await service.analyzeImage(imagePath, languageCode: '');

    expect(capturedFields()?.containsKey('language'), isFalse);
  });
}
