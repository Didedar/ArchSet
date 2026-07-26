import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

part 'app_database.g.dart';

/// Folders table for organizing notes
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#E8B731'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notes table with folder reference
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get audioPath => text().nullable()();
  TextColumn get folderId =>
      text().nullable()(); // Reference to Folders.id, null = "All Notes"
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Image metadata table for storing analysis and location.
///
/// A row with non-null [latitude]/[longitude] is what the artifacts map
/// renders as a pin.
class ImageMetadata extends Table {
  TextColumn get id => text()();
  TextColumn get imagePath =>
      text()(); // Normalized path (filename or relative)
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get analysisResult =>
      text().nullable()(); // JSON string from Gemini
  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get noteId =>
      text().nullable()(); // Reference to Notes.id the photo was taken in
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Free-form comments a user writes against a single artifact.
class ArtifactComments extends Table {
  TextColumn get id => text()();
  TextColumn get artifactId => text()(); // Reference to ImageMetadata.id
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Folders, Notes, ImageMetadata, ArtifactComments])
class AppDatabase extends _$AppDatabase {
  /// [executor] is only supplied by tests (e.g. an in-memory database);
  /// production always uses the lazily-connecting platform executor.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Runs against a caller-supplied executor so tests can use an in-memory
  /// database instead of the on-disk singleton.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  /// Indexes covering every filter/sort the repository actually issues.
  ///
  /// Without these, each list query is a full table scan plus an in-memory
  /// sort; cost grows linearly with the number of notes. Each statement
  /// mirrors one query in `NotesRepository`, with the equality columns first
  /// and the ordering column last so SQLite can satisfy both from the index.
  static const List<String> _indexStatements = [
    // watchAllNotes: WHERE is_deleted = 0 ORDER BY date DESC
    'CREATE INDEX IF NOT EXISTS idx_notes_deleted_date '
        'ON notes (is_deleted, date DESC)',
    // watchNotesInFolder, both the folder and the "uncategorised" branch.
    'CREATE INDEX IF NOT EXISTS idx_notes_folder_deleted_date '
        'ON notes (folder_id, is_deleted, date DESC)',
    // watchFolderNoteCounts: WHERE is_deleted = 0 GROUP BY folder_id.
    // Ordering the columns filter-first lets SQLite group straight off the
    // index instead of building a temporary B-tree.
    'CREATE INDEX IF NOT EXISTS idx_notes_deleted_folder '
        'ON notes (is_deleted, folder_id)',
    // watchAllFolders: WHERE is_deleted = 0 ORDER BY created_at ASC
    'CREATE INDEX IF NOT EXISTS idx_folders_deleted_created '
        'ON folders (is_deleted, created_at)',
    // ImageMetadata is looked up by normalised path on every embedded image.
    'CREATE INDEX IF NOT EXISTS idx_image_metadata_path '
        'ON image_metadata (image_path)',
  ];

  Future<void> _createIndexes() async {
    for (final statement in _indexStatements) {
      await customStatement(statement);
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Create Folders table
        await m.createTable(folders);

        // Rename folderName to folderId in Notes
        // Since we can't easily rename, we'll add folderId column
        // The old folderName column will be ignored (drift handles missing columns)
        await m.addColumn(notes, notes.folderId);
      }
      if (from < 3) {
        await m.addColumn(notes, notes.updatedAt);
      }
      if (from < 4) {
        // Add isDeleted column to both tables
        await m.addColumn(notes, notes.isDeleted);
        await m.addColumn(folders, folders.isDeleted);
      }
      if (from < 5) {
        // Add updatedAt column to Folders
        await m.addColumn(folders, folders.updatedAt);
      }
      if (from < 6) {
        // Add ImageMetadata table
        await m.createTable(imageMetadata);
      }
      if (from < 7) {
        // Backfill the query indexes onto existing installs.
        await _createIndexes();
      }
      if (from < 8) {
        // Artifacts map: link photos back to their note and give them the
        // same updatedAt/isDeleted shape Notes and Folders use for sync.
        // Pre-existing rows keep noteId == null and still render on the map.
        await m.addColumn(imageMetadata, imageMetadata.noteId);
        await m.addColumn(imageMetadata, imageMetadata.updatedAt);
        await m.addColumn(imageMetadata, imageMetadata.isDeleted);
        await m.createTable(artifactComments);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_app_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  /// Clear all data from the database
  Future<void> clearAllData() async {
    await delete(notes).go();
    await delete(folders).go();
  }
}
