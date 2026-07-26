import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
// `show Value` keeps drift's `isNull` query helper from shadowing the
// matcher of the same name.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the repository against a real in-memory database, because the
/// interesting behaviour lives in the SQL joins and aggregation rather than
/// in Dart.
void main() {
  late AppDatabase database;
  late ArtifactsRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ArtifactsRepository(database);
  });

  tearDown(() => database.close());

  Future<void> insertArtifact(
    String id, {
    double? latitude = 10.0,
    double? longitude = 20.0,
    String? noteId,
    String? analysisResult,
    bool isDeleted = false,
    DateTime? capturedAt,
  }) {
    return database
        .into(database.imageMetadata)
        .insert(
          ImageMetadataCompanion.insert(
            id: id,
            imagePath: '/photos/$id.jpg',
            latitude: Value(latitude),
            longitude: Value(longitude),
            analysisResult: Value(analysisResult),
            capturedAt: capturedAt ?? DateTime(2026, 1, 1),
            noteId: Value(noteId),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  Future<void> insertNote(
    String id, {
    String title = 'Trench A',
    bool isDeleted = false,
  }) {
    return database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            title: title,
            content: '',
            date: DateTime(2026, 1, 1),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  group('watchLocatedArtifacts', () {
    test('emits only artifacts that have both coordinates', () async {
      await insertArtifact('with-coords');
      await insertArtifact('no-lat', latitude: null);
      await insertArtifact('no-lng', longitude: null);

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.map((a) => a.id), ['with-coords']);
    });

    test('excludes soft-deleted artifacts', () async {
      await insertArtifact('live');
      await insertArtifact('deleted', isDeleted: true);

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.map((a) => a.id), ['live']);
    });

    test('orders newest first', () async {
      await insertArtifact('older', capturedAt: DateTime(2026, 1, 1));
      await insertArtifact('newer', capturedAt: DateTime(2026, 6, 1));

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.map((a) => a.id), ['newer', 'older']);
    });

    test('joins the note title', () async {
      await insertNote('note-1', title: 'Sector B');
      await insertArtifact('a1', noteId: 'note-1');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.single.noteTitle, 'Sector B');
    });

    test('leaves noteTitle null when the note was deleted', () async {
      await insertNote('note-1', isDeleted: true);
      await insertArtifact('a1', noteId: 'note-1');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.single.noteTitle, isNull);
    });

    test('survives an artifact whose noteId matches no note', () async {
      await insertArtifact('a1', noteId: 'missing-note');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.single.id, 'a1');
      expect(artifacts.single.noteTitle, isNull);
    });

    test('counts only live comments', () async {
      await insertArtifact('a1');
      await repository.addComment('a1', 'first');
      final second = await repository.addComment('a1', 'second');
      await repository.deleteComment(second);

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.single.commentCount, 1);
    });

    test('does not multiply rows when an artifact has many comments', () async {
      await insertArtifact('a1');
      await insertArtifact('a2');
      await repository.addComment('a1', 'one');
      await repository.addComment('a1', 'two');
      await repository.addComment('a1', 'three');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.length, 2);
      expect(artifacts.firstWhere((a) => a.id == 'a1').commentCount, 3);
      expect(artifacts.firstWhere((a) => a.id == 'a2').commentCount, 0);
    });

    test('decodes the Gemini analysis JSON', () async {
      await insertArtifact(
        'a1',
        analysisResult:
            '{"physical_characteristics":{"object_type":"Arrowhead"}}',
      );

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.single.isAnalyzed, isTrue);
      expect(artifacts.single.displayTitle, 'Arrowhead');
    });

    test('treats malformed analysis JSON as no analysis', () async {
      await insertArtifact('a1', analysisResult: 'not json at all');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.single.isAnalyzed, isFalse);
    });
  });

  group('watchUnlocatedCount', () {
    test('counts artifacts missing either coordinate', () async {
      await insertArtifact('located');
      await insertArtifact('no-lat', latitude: null);
      await insertArtifact('no-lng', longitude: null);
      await insertArtifact('deleted', latitude: null, isDeleted: true);

      expect(await repository.watchUnlocatedCount().first, 2);
    });

    test('is zero when everything has coordinates', () async {
      await insertArtifact('a1');

      expect(await repository.watchUnlocatedCount().first, 0);
    });
  });

  group('comments', () {
    test('addComment persists a trimmed body and returns its id', () async {
      await insertArtifact('a1');

      final id = await repository.addComment('a1', '  needs cleaning  ');
      final comments = await repository.watchComments('a1').first;

      expect(comments.single.id, id);
      expect(comments.single.body, 'needs cleaning');
    });

    test('addComment rejects a blank body', () async {
      await insertArtifact('a1');

      expect(() => repository.addComment('a1', '   '), throwsArgumentError);
    });

    test('updateComment rejects a blank body', () async {
      await insertArtifact('a1');
      final id = await repository.addComment('a1', 'original');

      expect(() => repository.updateComment(id, '  '), throwsArgumentError);
      final comments = await repository.watchComments('a1').first;
      expect(comments.single.body, 'original');
    });

    test('updateComment rewrites the body', () async {
      await insertArtifact('a1');
      final id = await repository.addComment('a1', 'original');

      await repository.updateComment(id, 'revised');

      final comments = await repository.watchComments('a1').first;
      expect(comments.single.body, 'revised');
    });

    test('deleteComment soft-deletes so the tombstone can sync', () async {
      await insertArtifact('a1');
      final id = await repository.addComment('a1', 'gone');

      await repository.deleteComment(id);

      expect(await repository.watchComments('a1').first, isEmpty);
      final raw = await (database.select(
        database.artifactComments,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(raw.isDeleted, isTrue);
    });

    test(
      'watchComments returns oldest first and scopes to one artifact',
      () async {
        await insertArtifact('a1');
        await insertArtifact('a2');
        await repository.addComment('a1', 'first');
        await repository.addComment('a1', 'second');
        await repository.addComment('a2', 'other artifact');

        final comments = await repository.watchComments('a1').first;

        expect(comments.map((c) => c.body), ['first', 'second']);
      },
    );
  });
}
