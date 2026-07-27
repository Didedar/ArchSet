import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';
// `show Value` keeps drift's `isNull` query helper from shadowing the
// matcher of the same name.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises NotesRepository against a real in-memory database.
///
/// A2 makes every local write stamp `updatedAt = now()` and
/// `pendingSync = true` so a later sync layer can select dirty rows with
/// `WHERE pending_sync = 1`. These tests read the row back from SQLite
/// after each write instead of mocking the database, because the behaviour
/// under test is exactly what ends up persisted.
void main() {
  late AppDatabase database;
  late NotesRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NotesRepository(database);
  });

  tearDown(() => database.close());

  Note note(
    String id, {
    String title = 'Title',
    String content = 'Content',
    DateTime? date,
    String? audioPath,
    String? folderId,
  }) {
    return Note(
      id: id,
      title: title,
      content: content,
      date: date ?? DateTime(2026, 1, 1),
      audioPath: audioPath,
      folderId: folderId,
      isDeleted: false,
      pendingSync: false,
    );
  }

  Folder folder(
    String id, {
    String name = 'Folder',
    String color = '#E8B731',
  }) {
    return Folder(
      id: id,
      name: name,
      color: color,
      createdAt: DateTime(2026, 1, 1),
      isDeleted: false,
      pendingSync: false,
    );
  }

  Future<Note> readNote(String id) async => (await repository.getNoteById(id))!;

  Future<Folder> readFolder(String id) async =>
      (await repository.getFolderById(id))!;

  /// Simulates a row that a previous sync already cleared, so a later
  /// assertion that pendingSync flips back to true is actually meaningful
  /// (rather than trivially true because it was never cleared).
  Future<void> clearNoteFlag(String id) =>
      (database.update(database.notes)..where((t) => t.id.equals(id))).write(
        const NotesCompanion(pendingSync: Value(false)),
      );

  Future<void> clearFolderFlag(String id) =>
      (database.update(database.folders)..where((t) => t.id.equals(id)))
          .write(const FoldersCompanion(pendingSync: Value(false)));

  group('insertNote', () {
    test('stamps pendingSync=true and a fresh updatedAt', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 2));

      await repository.insertNote(note('n1'));

      final saved = await readNote('n1');
      expect(saved.pendingSync, isTrue);
      expect(saved.updatedAt, isNotNull);
      expect(saved.updatedAt!.isAfter(before), isTrue);
    });

    test('persists the given diary date unchanged', () async {
      final date = DateTime(2020, 5, 17);

      await repository.insertNote(note('n1', date: date));

      final saved = await readNote('n1');
      expect(saved.date, date);
    });
  });

  group('updateNote', () {
    test('flips an already-synced note back to pendingSync=true', () async {
      await repository.insertNote(note('n1'));
      await clearNoteFlag('n1');

      await repository.updateNote(note('n1', title: 'Updated'));

      final saved = await readNote('n1');
      expect(saved.pendingSync, isTrue);
      expect(saved.title, 'Updated');
    });

    test('never overwrites the immutable diary date', () async {
      final originalDate = DateTime(2020, 5, 17);
      await repository.insertNote(note('n1', date: originalDate));
      await clearNoteFlag('n1');

      // The incoming Note carries a different `date`; updateNote must not
      // apply it since `date` is the immutable diary date.
      await repository.updateNote(
        note('n1', date: DateTime(2099, 1, 1), title: 'Renamed'),
      );

      final saved = await readNote('n1');
      expect(saved.date, originalDate);
      expect(saved.title, 'Renamed');
    });

    test('bumps updatedAt forward from a stale value', () async {
      await repository.insertNote(note('n1'));
      await (database.update(database.notes)..where((t) => t.id.equals('n1')))
          .write(
            NotesCompanion(
              pendingSync: const Value(false),
              updatedAt: Value(DateTime(2000, 1, 1)),
            ),
          );

      await repository.updateNote(note('n1', title: 'Updated'));

      final saved = await readNote('n1');
      expect(saved.updatedAt!.isAfter(DateTime(2000, 1, 2)), isTrue);
    });

    test('updates content, audioPath and folderId', () async {
      await repository.insertNote(note('n1'));
      await clearNoteFlag('n1');

      await repository.updateNote(
        note(
          'n1',
          title: 'New title',
          content: 'New content',
          audioPath: '/audio/n1.m4a',
          folderId: 'folder-1',
        ),
      );

      final saved = await readNote('n1');
      expect(saved.title, 'New title');
      expect(saved.content, 'New content');
      expect(saved.audioPath, '/audio/n1.m4a');
      expect(saved.folderId, 'folder-1');
    });
  });

  group('moveNoteToFolder', () {
    test('sets folderId and flips pendingSync back to true', () async {
      await repository.insertNote(note('n1'));
      await clearNoteFlag('n1');

      await repository.moveNoteToFolder('n1', 'folder-2');

      final saved = await readNote('n1');
      expect(saved.folderId, 'folder-2');
      expect(saved.pendingSync, isTrue);
    });
  });

  group('deleteNote', () {
    test('soft-deletes and flips pendingSync back to true', () async {
      await repository.insertNote(note('n1'));
      await clearNoteFlag('n1');

      await repository.deleteNote('n1');

      final saved = await readNote('n1');
      expect(saved.isDeleted, isTrue);
      expect(saved.pendingSync, isTrue);
    });
  });

  group('createFolder', () {
    test('stamps pendingSync=true and a fresh updatedAt', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 2));

      await repository.createFolder(folder('f1'));

      final saved = await readFolder('f1');
      expect(saved.pendingSync, isTrue);
      expect(saved.updatedAt, isNotNull);
      expect(saved.updatedAt!.isAfter(before), isTrue);
    });
  });

  group('updateFolder', () {
    test('flips pendingSync back to true, bumps updatedAt, edits fields', () async {
      await repository.createFolder(folder('f1', name: 'Original'));
      await clearFolderFlag('f1');

      await repository.updateFolder(
        folder('f1', name: 'Renamed', color: '#ABCDEF'),
      );

      final saved = await readFolder('f1');
      expect(saved.name, 'Renamed');
      expect(saved.color, '#ABCDEF');
      expect(saved.pendingSync, isTrue);
    });
  });

  group('deleteFolder', () {
    test('reparents child notes to null and soft-deletes the folder', () async {
      await repository.createFolder(folder('f1'));
      await repository.insertNote(note('n1', folderId: 'f1'));
      await repository.insertNote(note('n2', folderId: 'f1'));
      await clearFolderFlag('f1');
      await clearNoteFlag('n1');
      await clearNoteFlag('n2');

      await repository.deleteFolder('f1');

      final n1 = await readNote('n1');
      final n2 = await readNote('n2');
      final f1 = await readFolder('f1');

      expect(n1.folderId, isNull);
      expect(n1.pendingSync, isTrue);
      expect(n2.folderId, isNull);
      expect(n2.pendingSync, isTrue);
      expect(f1.isDeleted, isTrue);
      expect(f1.pendingSync, isTrue);
    });

    test('does not touch notes belonging to a different folder', () async {
      await repository.createFolder(folder('f1'));
      await repository.createFolder(folder('f2'));
      await repository.insertNote(note('n1', folderId: 'f2'));
      await clearNoteFlag('n1');

      await repository.deleteFolder('f1');

      final n1 = await readNote('n1');
      expect(n1.folderId, 'f2');
      expect(n1.pendingSync, isFalse);
    });
  });
}
