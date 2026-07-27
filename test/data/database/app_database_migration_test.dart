import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/artifacts_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Verifies the v6 -> v9 upgrade against a database built with the real v6
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

  test('upgrades a v6 database to v9 and keeps existing photos', () async {
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

    expect(database.schemaVersion, 9);
    expect(rows.single.id, 'legacy');
    expect(rows.single.latitude, 12.5);
    // New columns take their defaults rather than dropping the row.
    expect(rows.single.noteId, isNull);
    expect(rows.single.updatedAt, isNull);
    expect(rows.single.isDeleted, isFalse);
  });

  test('upgrades a v8 database to v9, adding sync columns with safe defaults', () async {
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

    expect(database.schemaVersion, 9);
    expect(notes.single.pendingSync, isFalse);
    expect(notes.single.ownerKey, isNull);
    expect(folders.single.pendingSync, isFalse);
    expect(folders.single.ownerKey, isNull);
  });

  test('the migrated v9 notes table accepts the new sync columns', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.opened(buildV8Database()),
    );
    addTearDown(database.close);

    await database.into(database.notes).insert(
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

  test('a migrated legacy photo still appears on the map', () async {
    final raw = buildV6Database();
    raw.execute(
      "INSERT INTO image_metadata "
      "(id, image_path, latitude, longitude, analysis_result, captured_at) "
      "VALUES ('legacy', '/photos/legacy.jpg', 12.5, 41.9, NULL, 1767225600)",
    );

    final database = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(database.close);
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

  test('a fresh database is created directly at v9', () async {
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
}
