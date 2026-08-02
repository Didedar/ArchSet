import 'package:archset_r2/data/current_owner_holder.dart';
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
///
/// The `ownerKey stamping` / `owner-scoped reads` groups close a critical
/// cross-account leak: previously nothing stamped `ownerKey` on write and
/// nothing filtered reads by it, so every row (including ones pulled from
/// the server for a signed-in user) had `ownerKey == null` and
/// `ClaimService`/`watchAllNotes` could sweep or display one account's rows
/// under another. [CurrentOwnerHolder] is the shared, mutable "who owns
/// local data right now" cell -- set by [SessionCubit] on auth transitions.
void main() {
  late AppDatabase database;
  late NotesRepository repository;
  late CurrentOwnerHolder ownerHolder;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    ownerHolder = CurrentOwnerHolder();
    repository = NotesRepository(database, ownerHolder: ownerHolder);
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

  Folder folder(String id, {String name = 'Folder', String color = '#E8B731'}) {
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
      (database.update(database.folders)..where((t) => t.id.equals(id))).write(
        const FoldersCompanion(pendingSync: Value(false)),
      );

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
      await (database.update(
        database.notes,
      )..where((t) => t.id.equals('n1'))).write(
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
    test(
      'flips pendingSync back to true, bumps updatedAt, edits fields',
      () async {
        await repository.createFolder(folder('f1', name: 'Original'));
        await clearFolderFlag('f1');

        await repository.updateFolder(
          folder('f1', name: 'Renamed', color: '#ABCDEF'),
        );

        final saved = await readFolder('f1');
        expect(saved.name, 'Renamed');
        expect(saved.color, '#ABCDEF');
        expect(saved.pendingSync, isTrue);
      },
    );
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

  group('ownerKey stamping', () {
    test('insertNote stamps ownerKey from the current owner holder', () async {
      ownerHolder.value = 'me';

      await repository.insertNote(note('n1'));

      final saved = await readNote('n1');
      expect(saved.ownerKey, 'me');
    });

    test('insertNote stamps a null ownerKey for a guest holder', () async {
      ownerHolder.value = null;

      await repository.insertNote(note('n1'));

      final saved = await readNote('n1');
      expect(saved.ownerKey, isNull);
    });

    test('updateNote stamps ownerKey from the current owner holder', () async {
      await repository.insertNote(note('n1'));
      ownerHolder.value = 'me';

      await repository.updateNote(note('n1', title: 'Updated'));

      final saved = await readNote('n1');
      expect(saved.ownerKey, 'me');
    });

    test(
      'moveNoteToFolder stamps ownerKey from the current owner holder',
      () async {
        await repository.insertNote(note('n1'));
        ownerHolder.value = 'me';

        await repository.moveNoteToFolder('n1', 'folder-2');

        final saved = await readNote('n1');
        expect(saved.ownerKey, 'me');
      },
    );

    test('deleteNote stamps ownerKey from the current owner holder', () async {
      await repository.insertNote(note('n1'));
      ownerHolder.value = 'me';

      await repository.deleteNote('n1');

      final saved = await readNote('n1');
      expect(saved.ownerKey, 'me');
    });

    test(
      'createFolder stamps ownerKey from the current owner holder',
      () async {
        ownerHolder.value = 'me';

        await repository.createFolder(folder('f1'));

        final saved = await readFolder('f1');
        expect(saved.ownerKey, 'me');
      },
    );

    test(
      'updateFolder stamps ownerKey from the current owner holder',
      () async {
        await repository.createFolder(folder('f1'));
        ownerHolder.value = 'me';

        await repository.updateFolder(folder('f1', name: 'Renamed'));

        final saved = await readFolder('f1');
        expect(saved.ownerKey, 'me');
      },
    );

    test('deleteFolder stamps ownerKey on reparented notes and the deleted '
        'folder', () async {
      await repository.createFolder(folder('f1'));
      await repository.insertNote(note('n1', folderId: 'f1'));
      ownerHolder.value = 'me';

      await repository.deleteFolder('f1');

      final n1 = await readNote('n1');
      final f1 = await readFolder('f1');
      expect(n1.ownerKey, 'me');
      expect(f1.ownerKey, 'me');
    });
  });

  group('owner-scoped reads', () {
    /// Inserts a note directly (bypassing the repository) so it can be
    /// stamped with an arbitrary owner, simulating a row that belongs to a
    /// different, already-authenticated account.
    Future<void> insertRawNote(
      String id, {
      required String ownerKey,
      String? folderId,
    }) => database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            title: 'Title $id',
            content: 'Content $id',
            date: DateTime(2026, 1, 1),
            folderId: Value(folderId),
            ownerKey: Value(ownerKey),
          ),
        );

    Future<void> insertRawFolder(String id, {required String ownerKey}) =>
        database
            .into(database.folders)
            .insert(
              FoldersCompanion.insert(
                id: id,
                name: 'Folder $id',
                createdAt: DateTime(2026, 1, 1),
                ownerKey: Value(ownerKey),
              ),
            );

    test("watchAllNotes returns the current owner's rows plus unclaimed guest "
        "rows, but not another account's", () async {
      ownerHolder.value = 'me';
      await repository.insertNote(note('mine'));
      ownerHolder.value = null;
      await repository.insertNote(note('guest'));
      await insertRawNote('other', ownerKey: 'other-user');
      ownerHolder.value = 'me';

      final result = await repository.watchAllNotes().first;

      final ids = result.map((n) => n.id).toSet();
      expect(ids, {'mine', 'guest'});
    });

    test("watchAllFolders returns the current owner's rows plus unclaimed "
        "guest rows, but not another account's", () async {
      ownerHolder.value = 'me';
      await repository.createFolder(folder('mine'));
      ownerHolder.value = null;
      await repository.createFolder(folder('guest'));
      await insertRawFolder('other', ownerKey: 'other-user');
      ownerHolder.value = 'me';

      final result = await repository.watchAllFolders().first;

      final ids = result.map((f) => f.id).toSet();
      expect(ids, {'mine', 'guest'});
    });

    test('watchNotesInFolder scopes both the uncategorised and specific-folder '
        'branches to the current owner', () async {
      await repository.createFolder(folder('f1'));
      await insertRawNote(
        'other-in-folder',
        ownerKey: 'other-user',
        folderId: 'f1',
      );
      ownerHolder.value = 'me';
      await repository.insertNote(note('mine-in-folder', folderId: 'f1'));
      await repository.insertNote(note('mine-uncategorised'));

      final inFolder = await repository.watchNotesInFolder('f1').first;
      final uncategorised = await repository.watchNotesInFolder(null).first;

      expect(inFolder.map((n) => n.id), ['mine-in-folder']);
      expect(uncategorised.map((n) => n.id), ['mine-uncategorised']);
    });

    test("watchAllNotesCount only counts the current owner's uncategorised "
        'notes', () async {
      await insertRawNote('other-1', ownerKey: 'other-user');
      ownerHolder.value = 'me';
      await repository.insertNote(note('mine-1'));
      await repository.insertNote(note('mine-2'));

      final count = await repository.watchAllNotesCount().first;

      expect(count, 2);
    });

    test(
      "watchFolderNoteCounts only counts the current owner's notes",
      () async {
        await repository.createFolder(folder('f1'));
        await insertRawNote('other-1', ownerKey: 'other-user', folderId: 'f1');
        ownerHolder.value = 'me';
        await repository.insertNote(note('mine-1', folderId: 'f1'));

        final counts = await repository.watchFolderNoteCounts().first;

        expect(counts['f1'], 1);
      },
    );

    /// `pendingSyncCount()` drives the "you have unsent work" warning shown
    /// before sign-out. It is the only query in the repository whose result
    /// the user never sees directly -- they only see a dialog appear or not
    /// appear -- so a wrong predicate here fails silently. That makes it
    /// worth pinning both halves of its WHERE clause explicitly.
    group('pendingSyncCount', () {
      test('counts only rows that are actually dirty', () async {
        ownerHolder.value = 'me';
        await repository.insertNote(note('dirty-1'));
        await repository.insertNote(note('dirty-2'));
        await repository.insertNote(note('clean-1'));
        await clearNoteFlag('clean-1');

        expect(await repository.pendingSyncCount(), 2);
      });

      test("does not count another account's dirty rows", () async {
        // Same cross-account leak this whole group exists to prevent: without
        // the owner filter this would report a stranger's unsent work as the
        // signed-in user's own.
        await insertRawNote('other-1', ownerKey: 'other-user');
        await (database.update(database.notes)
              ..where((t) => t.id.equals('other-1')))
            .write(const NotesCompanion(pendingSync: Value(true)));
        ownerHolder.value = 'me';
        await repository.insertNote(note('mine-1'));

        expect(await repository.pendingSyncCount(), 1);
      });

      test('is zero when everything has been synced', () async {
        ownerHolder.value = 'me';
        await repository.insertNote(note('n1'));
        await clearNoteFlag('n1');

        expect(await repository.pendingSyncCount(), 0);
      });

      test('counts a pending deletion as unsent work', () async {
        ownerHolder.value = 'me';
        await repository.insertNote(note('n1'));
        await clearNoteFlag('n1');
        await repository.deleteNote('n1');

        expect(await repository.pendingSyncCount(), 1);
      });
    });
  });
}
