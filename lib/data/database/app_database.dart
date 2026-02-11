import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

/// Image metadata table for storing analysis and location
class ImageMetadata extends Table {
  TextColumn get id => text()();
  TextColumn get imagePath =>
      text()(); // Normalized path (filename or relative)
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get analysisResult =>
      text().nullable()(); // JSON string from Gemini
  DateTimeColumn get capturedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Folders, Notes, ImageMetadata])
class AppDatabase extends _$AppDatabase {
  // Singleton instance
  static final AppDatabase _instance = AppDatabase._internal();

  // Factory constructor to return the same instance
  factory AppDatabase() => _instance;

  // Private constructor
  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
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
