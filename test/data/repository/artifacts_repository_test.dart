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

    test('drops an artifact entirely when its note was deleted', () async {
      // Previously this asserted the artifact stayed on the map with a null
      // title. That left a pin claiming a find whose entry no longer exists,
      // which is worse than not showing it: someone would go looking for the
      // context and find none. The pin now goes with the entry.
      await insertNote('note-1', isDeleted: true);
      await insertArtifact('a1', noteId: 'note-1');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts, isEmpty);
    });

    test('drops an artifact whose entry was hard-deleted', () async {
      // The editor hard-deletes once the server confirms, so the note row is
      // gone rather than tombstoned. This used to assert the opposite -- that
      // the pin survived with a null title -- because a left join to a missing
      // row and a photo attached to nothing both read as "notes.isDeleted IS
      // NULL". They are not the same thing, and treating them alike is what
      // left pins on the map for diaries the user had deleted.
      await insertArtifact('a1', noteId: 'missing-note');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts, isEmpty);
    });

    test('keeps a photo that was never attached to an entry', () async {
      // The other half, and the reason the rule cannot simply be "the note
      // must exist": a find photographed outside any entry has nothing to
      // outlive, and must stay on the map.
      await insertArtifact('a1');

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

  /// Deleting a diary has to take its finds off the map with it.
  ///
  /// A photographed artifact only exists as part of the entry it was
  /// photographed in; leaving its pin behind after the entry is gone means the
  /// map claims a find that has no record anywhere -- worse than not showing
  /// it, because a colleague would go looking for the context and find none.
  group('artifacts of a deleted note', () {
    Future<void> insertNoteRow(String id, {bool isDeleted = false}) {
      return database
          .into(database.notes)
          .insert(
            NotesCompanion.insert(
              id: id,
              title: 'Раскоп 3',
              content: '',
              date: DateTime(2026, 8, 2),
              isDeleted: Value(isDeleted),
            ),
          );
    }

    test('a pin disappears once its note is deleted', () async {
      await insertNoteRow('n1', isDeleted: true);
      await insertArtifact('a1', noteId: 'n1');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.map((a) => a.id), isNot(contains('a1')));
    });

    test('a pin stays while its note is alive', () async {
      await insertNoteRow('n1');
      await insertArtifact('a1', noteId: 'n1');

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.map((a) => a.id), contains('a1'));
    });

    test('an artifact attached to no note at all still shows', () async {
      // A photo taken outside any entry has no parent to be deleted, so the
      // join must not filter it out along with the orphans.
      await insertArtifact('a-loose', noteId: null);

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.map((a) => a.id), contains('a-loose'));
    });

    test('the unlocated count also ignores a deleted note\'s photos', () async {
      await insertNoteRow('n1', isDeleted: true);
      await insertArtifact('a1', noteId: 'n1', latitude: null, longitude: null);

      expect(await repository.watchUnlocatedCount().first, 0);
    });
  });

  /// The map opened from inside an entry shows only what was photographed in
  /// that entry -- a whole-dig map is the wrong answer when you are standing
  /// in one trench asking "what did I find here?".
  group('scoped to a single note', () {
    test('returns only that note\'s finds', () async {
      await insertNote('n1');
      await insertNote('n2');
      await insertArtifact('a1', noteId: 'n1');
      await insertArtifact('a2', noteId: 'n2');
      await insertArtifact('a-loose', noteId: null);

      final artifacts = await repository
          .watchLocatedArtifacts(noteId: 'n1')
          .first;

      expect(artifacts.map((a) => a.id), ['a1']);
    });

    test('without a noteId it still returns everything', () async {
      await insertNote('n1');
      await insertArtifact('a1', noteId: 'n1');
      await insertArtifact('a-loose', noteId: null);

      final artifacts = await repository.watchLocatedArtifacts().first;

      expect(artifacts.map((a) => a.id), containsAll(['a1', 'a-loose']));
    });

    test('a deleted note scoped to itself yields nothing', () async {
      await insertNote('n1', isDeleted: true);
      await insertArtifact('a1', noteId: 'n1');

      expect(
        await repository.watchLocatedArtifacts(noteId: 'n1').first,
        isEmpty,
      );
    });

    test('the unlocated count can be scoped too', () async {
      await insertNote('n1');
      await insertNote('n2');
      await insertArtifact('a1', noteId: 'n1', latitude: null);
      await insertArtifact('a2', noteId: 'n2', latitude: null);

      expect(await repository.watchUnlocatedCount(noteId: 'n1').first, 1);
      expect(await repository.watchUnlocatedCount().first, 2);
    });
  });
}
