import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Verifies the v6 -> v10 upgrade against a database built with the real v6
/// schema, because a broken migration corrupts existing users' data rather
/// than failing loudly in review.
void main() {
  /// The schema exactly as it shipped at version 6: no noteId/updatedAt/
  /// isDeleted on image_metadata, and no artifact_comments table.
  Database buildV6Database() {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE folders (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#E8B731',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      CREATE TABLE notes (
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date INTEGER NOT NULL,
        audio_path TEXT NULL,
        folder_id TEXT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      CREATE TABLE image_metadata (
        id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        latitude REAL NULL,
        longitude REAL NULL,
        analysis_result TEXT NULL,
        captured_at INTEGER NOT NULL,
        PRIMARY KEY (id)
      );
    ''');
    db.userVersion = 6;
    return db;
  }

  /// The schema exactly as it shipped at version 8: image_metadata already
  /// has noteId/updatedAt/isDeleted and artifact_comments exists (added in
  /// the v6 -> v8 migration), but folders/notes are still missing the
  /// pendingSync/ownerKey sync columns added in v9.
  Database buildV8Database() {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE folders (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#E8B731',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      CREATE TABLE notes (
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date INTEGER NOT NULL,
        audio_path TEXT NULL,
        folder_id TEXT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      CREATE TABLE image_metadata (
        id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        latitude REAL NULL,
        longitude REAL NULL,
        analysis_result TEXT NULL,
        captured_at INTEGER NOT NULL,
        note_id TEXT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      CREATE TABLE artifact_comments (
        id TEXT NOT NULL,
        artifact_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
    ''');
    db.userVersion = 8;
    return db;
  }

  /// The schema exactly as it shipped at version 9: v8 plus the per-row sync
  /// bookkeeping (`pending_sync`, `owner_key`), and before `base_revision`.
  Database buildV9Database() {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE folders (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#E8B731',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        owner_key TEXT NULL,
        PRIMARY KEY (id)
      );
      CREATE TABLE notes (
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date INTEGER NOT NULL,
        audio_path TEXT NULL,
        folder_id TEXT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        owner_key TEXT NULL,
        PRIMARY KEY (id)
      );
      CREATE TABLE image_metadata (
        id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        latitude REAL NULL,
        longitude REAL NULL,
        analysis_result TEXT NULL,
        captured_at INTEGER NOT NULL,
        note_id TEXT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      CREATE TABLE artifact_comments (
        id TEXT NOT NULL,
        artifact_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
    ''');
    db.userVersion = 9;
    return db;
  }

  test('upgrades a v6 database to v11 and keeps existing photos', () async {
    final raw = buildV6Database();
    // A photo captured before the upgrade: has coordinates, no note link.
    raw.execute(
      "INSERT INTO image_metadata "
      "(id, image_path, latitude, longitude, analysis_result, captured_at) "
      "VALUES ('legacy', '/photos/legacy.jpg', 12.5, 41.9, NULL, 1767225600)",
    );

    final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(database.close);

    // Any query forces the migration to run.
    final rows = await database.select(database.imageMetadata).get();

    expect(database.schemaVersion, 13);
    expect(rows.single.id, 'legacy');
    expect(rows.single.latitude, 12.5);
    // New columns take their defaults rather than dropping the row.
    expect(rows.single.noteId, isNull);
    // Tombstoned by the v13 sweep rather than dropped: the row survives the
    // upgrade (that is what this test is about), but a photo with no note
    // link predates that column and its entry is gone, so it no longer
    // belongs on the map. `updatedAt` is set by the sweep so the removal
    // reaches the server too.
    expect(rows.single.isDeleted, isTrue);
    expect(rows.single.updatedAt, isNotNull);
  });

  test(
    'upgrades a v8 database to v11, adding sync columns with safe defaults',
    () async {
      final raw = buildV8Database();
      raw.execute(
        "INSERT INTO folders (id, name, color, created_at, is_deleted) "
        "VALUES ('f-legacy','Old','#E8B731',1767225600,0)",
      );
      raw.execute(
        "INSERT INTO notes (id, title, content, date, is_deleted) "
        "VALUES ('n-legacy','T','C',1767225600,0)",
      );
      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      final notes = await database.select(database.notes).get();
      final folders = await database.select(database.folders).get();

      expect(database.schemaVersion, 13);
      expect(notes.single.pendingSync, isFalse);
      expect(notes.single.ownerKey, isNull);
      expect(folders.single.pendingSync, isFalse);
      expect(folders.single.ownerKey, isNull);
    },
  );

  /// The schema exactly as it shipped at version 10: v9 plus `base_revision`
  /// on the four synced tables, and before authorship/sharing.
  Database buildV10Database() {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE folders (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#E8B731',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        owner_key TEXT NULL,
        base_revision INTEGER NULL,
        PRIMARY KEY (id)
      );
      CREATE TABLE notes (
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date INTEGER NOT NULL,
        audio_path TEXT NULL,
        folder_id TEXT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        pending_sync INTEGER NOT NULL DEFAULT 0,
        owner_key TEXT NULL,
        base_revision INTEGER NULL,
        PRIMARY KEY (id)
      );
      CREATE TABLE image_metadata (
        id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        latitude REAL NULL,
        longitude REAL NULL,
        analysis_result TEXT NULL,
        captured_at INTEGER NOT NULL,
        note_id TEXT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        base_revision INTEGER NULL,
        PRIMARY KEY (id)
      );
      CREATE TABLE artifact_comments (
        id TEXT NOT NULL,
        artifact_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        base_revision INTEGER NULL,
        PRIMARY KEY (id)
      );
    ''');
    db.userVersion = 10;
    return db;
  }

  test('upgrades a v9 database to v11, adding baseRevision without losing '
      'rows', () async {
    final raw = buildV9Database();
    raw.execute(
      "INSERT INTO folders (id, name, color, created_at, is_deleted, "
      "pending_sync, owner_key) "
      "VALUES ('f-legacy','Раскоп 3','#E8B731',1767225600,0,1,'ivan')",
    );
    raw.execute(
      "INSERT INTO notes (id, title, content, date, is_deleted, pending_sync, "
      "owner_key) VALUES ('n-legacy','Слой 2','C',1767225600,0,1,'ivan')",
    );
    raw.execute(
      "INSERT INTO image_metadata (id, image_path, captured_at, is_deleted) "
      "VALUES ('a-legacy','/photos/a.jpg',1767225600,0)",
    );
    raw.execute(
      "INSERT INTO artifact_comments (id, artifact_id, body, created_at, "
      "is_deleted) VALUES ('c-legacy','a-legacy','Керамика',1767225600,0)",
    );
    final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(database.close);

    final notes = await database.select(database.notes).get();
    final folders = await database.select(database.folders).get();
    final artifacts = await database.select(database.imageMetadata).get();
    final comments = await database.select(database.artifactComments).get();

    expect(database.schemaVersion, 13);

    // Null, not zero: a row that has never been to the server has no revision
    // to have been based on, and zero would look like a real one.
    expect(notes.single.baseRevision, isNull);
    expect(folders.single.baseRevision, isNull);
    expect(artifacts.single.baseRevision, isNull);
    expect(comments.single.baseRevision, isNull);

    // The migration must not disturb what was already there -- in particular
    // the dirty flags, which are what a pending sync depends on.
    expect(notes.single.title, 'Слой 2');
    expect(notes.single.pendingSync, isTrue);
    expect(notes.single.ownerKey, 'ivan');
    expect(folders.single.name, 'Раскоп 3');
    expect(folders.single.pendingSync, isTrue);
    expect(artifacts.single.imagePath, '/photos/a.jpg');
    expect(comments.single.body, 'Керамика');
  });

  test(
    'upgrades a v10 database to v11, adding authorship and sharing',
    () async {
      final raw = buildV10Database();
      raw.execute(
        "INSERT INTO folders (id, name, color, created_at, is_deleted, "
        "pending_sync, owner_key) "
        "VALUES ('f-legacy','Раскоп 3','#E8B731',1767225600,0,1,'ivan')",
      );
      raw.execute(
        "INSERT INTO notes (id, title, content, date, is_deleted, pending_sync, "
        "owner_key) VALUES ('n-legacy','Слой 2','C',1767225600,0,1,'ivan')",
      );
      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      final notes = await database.select(database.notes).get();
      final folders = await database.select(database.folders).get();

      expect(database.schemaVersion, 13);

      // Null, not the owner: rows that predate authorship have no recorded
      // author, and inventing one would claim knowledge the database never had.
      expect(notes.single.authorId, isNull);
      expect(folders.single.authorId, isNull);

      // Nothing is shared until the server says so.
      expect(folders.single.isShared, isFalse);

      // Existing state must survive untouched -- especially the dirty flags a
      // pending sync depends on.
      expect(notes.single.title, 'Слой 2');
      expect(notes.single.pendingSync, isTrue);
      expect(notes.single.ownerKey, 'ivan');
      expect(folders.single.name, 'Раскоп 3');
    },
  );

  test('the migrated v9 notes table accepts the new sync columns', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.opened(buildV8Database()),
    );
    addTearDown(database.close);

    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n-new',
            title: 'T',
            content: 'C',
            date: DateTime(2026, 1, 1),
            pendingSync: const Value(true),
            ownerKey: const Value('user-1'),
          ),
        );

    final row = await (database.select(
      database.notes,
    )..where((t) => t.id.equals('n-new'))).getSingle();

    expect(row.pendingSync, isTrue);
    expect(row.ownerKey, 'user-1');
  });

  test('a migrated photo appears on the map when its entry is alive', () async {
    // The point of the migration is that a photo captured before the sync
    // columns existed keeps working. It has to still have an entry, though --
    // the version of this test that used a note-less row was asserting the
    // rule that left deleted diaries' pins on the map.
    final raw = buildV6Database();
    raw.execute(
      "INSERT INTO notes (id, title, content, date) "
      "VALUES ('n-legacy','Trench A','',1767225600)",
    );
    raw.execute(
      "INSERT INTO image_metadata "
      "(id, image_path, latitude, longitude, analysis_result, captured_at) "
      "VALUES ('legacy', '/photos/legacy.jpg', 12.5, 41.9, NULL, 1767225600)",
    );

    final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(database.close);

    // Attach it the way the editor would, after the column exists.
    await database.customStatement(
      "UPDATE image_metadata SET note_id = 'n-legacy', is_deleted = 0",
    );
    final repository = ArtifactsRepository(database);

    final artifacts = await repository.watchLocatedArtifacts().first;

    expect(artifacts.single.id, 'legacy');
    expect(artifacts.single.commentCount, 0);
  });

  test('creates a usable artifact_comments table during the upgrade', () async {
    final raw = buildV6Database();
    raw.execute(
      "INSERT INTO image_metadata "
      "(id, image_path, latitude, longitude, analysis_result, captured_at) "
      "VALUES ('legacy', '/photos/legacy.jpg', 12.5, 41.9, NULL, 1767225600)",
    );

    final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(database.close);
    final repository = ArtifactsRepository(database);

    await repository.addComment('legacy', 'found near the hearth');

    final comments = await repository.watchComments('legacy').first;
    expect(comments.single.body, 'found near the hearth');
  });

  test('a fresh database is created directly at v11', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.imageMetadata)
        .insert(
          ImageMetadataCompanion.insert(
            id: 'new',
            imagePath: '/photos/new.jpg',
            capturedAt: DateTime(2026, 1, 1),
            latitude: const Value(1),
            longitude: const Value(2),
            noteId: const Value('note-1'),
          ),
        );

    final rows = await database.select(database.imageMetadata).get();
    expect(rows.single.noteId, 'note-1');
  });

  group('v12 sweeps up finds left behind by a deleted entry', () {
    /// Deleting a diary was meant to take its photographed finds with it, but
    /// for a long while only one of the two delete paths did so -- and the
    /// editor takes the other whenever the server confirms. Those artifacts
    /// are still here, and still alive on the server, so hiding them locally
    /// would leave them on a colleague's map. Tombstoning them with a fresh
    /// updatedAt is what actually removes them: the sync layer picks artifacts
    /// up by `updatedAt > lastSyncAt`.
    test('an orphaned find is tombstoned so the deletion syncs', () async {
      final raw = buildV8Database();
      raw.execute(
        "INSERT INTO notes (id, title, content, date, is_deleted) "
        "VALUES ('n-alive','T','C',1767225600,0)",
      );
      raw.execute(
        "INSERT INTO image_metadata "
        "(id, image_path, latitude, longitude, analysis_result, captured_at, note_id) "
        "VALUES ('a-orphan','/p/a.jpg',12.5,41.9,NULL,1767225600,'n-gone')",
      );
      raw.execute(
        "INSERT INTO image_metadata "
        "(id, image_path, latitude, longitude, analysis_result, captured_at, note_id) "
        "VALUES ('a-kept','/p/b.jpg',12.5,41.9,NULL,1767225600,'n-alive')",
      );

      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      final rows = await database.select(database.imageMetadata).get();
      final orphan = rows.firstWhere((r) => r.id == 'a-orphan');
      final kept = rows.firstWhere((r) => r.id == 'a-kept');

      expect(orphan.isDeleted, isTrue);
      expect(orphan.updatedAt, isNotNull, reason: 'so the removal reaches the server');
      expect(kept.isDeleted, isFalse, reason: 'its entry is still there');
    });

    test('a find whose entry was tombstoned is swept up too', () async {
      // v12 only looked for hard-deleted entries. A tombstoned one still
      // exists as a row, so its finds stayed alive on the server and kept
      // their pin on a colleague's map even while hidden here.
      final raw = buildV8Database();
      raw.execute(
        "INSERT INTO notes (id, title, content, date, is_deleted) "
        "VALUES ('n-tombstoned','T','C',1767225600,1)",
      );
      raw.execute(
        "INSERT INTO image_metadata "
        "(id, image_path, latitude, longitude, analysis_result, captured_at, note_id) "
        "VALUES ('a-soft','/p/d.jpg',12.5,41.9,NULL,1767225600,'n-tombstoned')",
      );

      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      final row = (await database.select(database.imageMetadata).get()).single;

      expect(row.isDeleted, isTrue);
      expect(row.updatedAt, isNotNull, reason: 'so the removal reaches the server');
    });

    test('a photo with no note link at all is swept up', () async {
      // Not an unattached find: every capture records its entry's id, so a row
      // without one predates that column and its entry is long gone. Sparing
      // these is what left July's pins on the map with no way to remove them.
      final raw = buildV8Database();
      raw.execute(
        "INSERT INTO image_metadata "
        "(id, image_path, latitude, longitude, analysis_result, captured_at) "
        "VALUES ('a-legacy','/p/c.jpg',12.5,41.9,NULL,1767225600)",
      );

      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      final row = (await database.select(database.imageMetadata).get()).single;

      expect(row.isDeleted, isTrue);
    });

    test('a find whose entry is alive is untouched', () async {
      final raw = buildV8Database();
      raw.execute(
        "INSERT INTO notes (id, title, content, date, is_deleted) "
        "VALUES ('n-alive2','T','C',1767225600,0)",
      );
      raw.execute(
        "INSERT INTO image_metadata "
        "(id, image_path, latitude, longitude, analysis_result, captured_at, note_id) "
        "VALUES ('a-live','/p/e.jpg',12.5,41.9,NULL,1767225600,'n-alive2')",
      );

      final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(database.close);

      final row = (await database.select(database.imageMetadata).get()).single;

      expect(row.isDeleted, isFalse);
    });
  });
}
