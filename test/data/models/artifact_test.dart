import 'package:archset_r2/data/models/artifact.dart';
import 'package:flutter_test/flutter_test.dart';

Artifact artifact({
  double? latitude = 10,
  double? longitude = 20,
  String? noteTitle,
  Map<String, dynamic>? analysis,
}) => Artifact(
  id: 'a1',
  imagePath: '/photos/a1.jpg',
  capturedAt: DateTime(2026, 1, 1),
  latitude: latitude,
  longitude: longitude,
  noteTitle: noteTitle,
  analysis: analysis,
);

void main() {
  group('hasLocation', () {
    test('is true only when both coordinates are present', () {
      expect(artifact().hasLocation, isTrue);
      expect(artifact(latitude: null).hasLocation, isFalse);
      expect(artifact(longitude: null).hasLocation, isFalse);
    });

    test('treats a zero coordinate as a real location', () {
      expect(artifact(latitude: 0, longitude: 0).hasLocation, isTrue);
    });
  });

  group('decodeAnalysis', () {
    test('decodes a JSON object', () {
      expect(Artifact.decodeAnalysis('{"a":1}'), {'a': 1});
    });

    test('returns null for null, blank, malformed, and non-object input', () {
      expect(Artifact.decodeAnalysis(null), isNull);
      expect(Artifact.decodeAnalysis('   '), isNull);
      expect(Artifact.decodeAnalysis('{not json'), isNull);
      expect(Artifact.decodeAnalysis('[1,2,3]'), isNull);
    });
  });

  group('displayTitle', () {
    test('prefers object_type', () {
      final subject = artifact(
        analysis: {
          'physical_characteristics': {
            'object_type': 'Arrowhead',
            'material': 'Bronze',
          },
        },
      );

      expect(subject.displayTitle, 'Arrowhead');
    });

    test('falls back to material when object_type is absent', () {
      final subject = artifact(
        analysis: {
          'physical_characteristics': {'material': 'Ceramics'},
        },
      );

      expect(subject.displayTitle, 'Ceramics');
    });

    test('skips Gemini placeholder values', () {
      final subject = artifact(
        analysis: {
          'physical_characteristics': {
            'object_type': 'unknown',
            'material': '  ',
          },
          'administrative_data': {'unique_code': 'неизвестно'},
        },
        noteTitle: 'Trench A',
      );

      expect(subject.displayTitle, 'Trench A');
    });

    test('falls back to the note title when there is no analysis', () {
      expect(artifact(noteTitle: 'Sector B').displayTitle, 'Sector B');
    });

    test('is null when nothing usable exists', () {
      expect(artifact().displayTitle, isNull);
    });

    test('ignores a non-map analysis section', () {
      final subject = artifact(
        analysis: {'physical_characteristics': 'not a map'},
        noteTitle: 'Trench A',
      );

      expect(subject.physicalCharacteristics, isNull);
      expect(subject.displayTitle, 'Trench A');
    });
  });

  test('isAnalyzed reflects whether an analysis was decoded', () {
    expect(artifact().isAnalyzed, isFalse);
    expect(artifact(analysis: const {}).isAnalyzed, isTrue);
  });

  test('value equality lets bloc skip identical states', () {
    expect(artifact(), equals(artifact()));
    expect(artifact(), isNot(equals(artifact(latitude: 99))));
  });
}
