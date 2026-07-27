import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/services/claim_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// D1: claiming guest data hands ownership of every still-unclaimed
/// (ownerKey IS NULL) local note/folder to the freshly authenticated
/// account and flags it pendingSync so the next push uploads it. Rows
/// already owned by a different account must never be re-owned or
/// re-dirtied -- that's what keeps switching accounts on a shared device
/// from leaking one account's edits into another's sync payload -- and
/// re-claiming for the account that already owns everything is a no-op.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<void> insertNote(
    String id, {
    String? ownerKey,
    bool pendingSync = false,
    DateTime? updatedAt,
  }) async {
    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            title: 'Title $id',
            content: 'Content $id',
            date: DateTime(2026, 1, 1),
            updatedAt: Value(updatedAt),
            ownerKey: Value(ownerKey),
            pendingSync: Value(pendingSync),
          ),
        );
  }

  Future<void> insertFolder(
    String id, {
    String? ownerKey,
    bool pendingSync = false,
    DateTime? updatedAt,
  }) async {
    await database
        .into(database.folders)
        .insert(
          FoldersCompanion.insert(
            id: id,
            name: 'Folder $id',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: Value(updatedAt),
            ownerKey: Value(ownerKey),
            pendingSync: Value(pendingSync),
          ),
        );
  }

  Future<Note> readNote(String id) => (database.select(
    database.notes,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<Folder> readFolder(String id) => (database.select(
    database.folders,
  )..where((t) => t.id.equals(id))).getSingle();

  test('claims every unclaimed note and folder, marks them pendingSync and '
      'owned by the new account, and returns the total rows claimed', () async {
    final untouchedUpdatedAt = DateTime(2025, 12, 1);
    await insertNote('note-1', updatedAt: untouchedUpdatedAt);
    await insertNote('note-2');
    await insertFolder('folder-1', updatedAt: untouchedUpdatedAt);

    final service = ClaimService(database);
    final claimed = await service.claimGuestData('user-1');

    expect(claimed, 3);

    final note1 = await readNote('note-1');
    expect(note1.ownerKey, 'user-1');
    expect(note1.pendingSync, isTrue);
    // Claiming changes ownership, not content: updatedAt (used for LWW)
    // is deliberately left as-is.
    expect(note1.updatedAt, untouchedUpdatedAt);

    final note2 = await readNote('note-2');
    expect(note2.ownerKey, 'user-1');
    expect(note2.pendingSync, isTrue);

    final folder1 = await readFolder('folder-1');
    expect(folder1.ownerKey, 'user-1');
    expect(folder1.pendingSync, isTrue);
    expect(folder1.updatedAt, untouchedUpdatedAt);
  });

  test('leaves rows already owned by a different account untouched and only '
      'claims the null-owner rows', () async {
    await insertNote('owned-note', ownerKey: 'user-1');
    await insertFolder('owned-folder', ownerKey: 'user-1');
    await insertNote('guest-note');
    await insertFolder('guest-folder');

    final service = ClaimService(database);
    final claimed = await service.claimGuestData('user-2');

    expect(claimed, 2);

    // Another account's rows keep their owner and clean flag: claiming
    // for user-2 must never re-own or re-dirty user-1's data.
    final ownedNote = await readNote('owned-note');
    expect(ownedNote.ownerKey, 'user-1');
    expect(ownedNote.pendingSync, isFalse);

    final ownedFolder = await readFolder('owned-folder');
    expect(ownedFolder.ownerKey, 'user-1');
    expect(ownedFolder.pendingSync, isFalse);

    final guestNote = await readNote('guest-note');
    expect(guestNote.ownerKey, 'user-2');
    expect(guestNote.pendingSync, isTrue);

    final guestFolder = await readFolder('guest-folder');
    expect(guestFolder.ownerKey, 'user-2');
    expect(guestFolder.pendingSync, isTrue);
  });

  test('re-logging in as the account that already owns every row claims '
      'nothing and leaves rows clean', () async {
    await insertNote('note-1', ownerKey: 'user-1');
    await insertFolder('folder-1', ownerKey: 'user-1');

    final service = ClaimService(database);
    final claimed = await service.claimGuestData('user-1');

    expect(claimed, 0);

    final note1 = await readNote('note-1');
    expect(note1.ownerKey, 'user-1');
    expect(note1.pendingSync, isFalse);

    final folder1 = await readFolder('folder-1');
    expect(folder1.ownerKey, 'user-1');
    expect(folder1.pendingSync, isFalse);
  });

  group('cross-account isolation on a shared device', () {
    test(
      'claiming for a second account on the same device only claims the '
      'fresh guest row and leaves the first account\'s clean data alone',
      () async {
        // user-1 already owns a clean (already-synced) note and folder on
        // this device -- e.g. they logged out without wiping local data.
        await insertNote('user1-note', ownerKey: 'user-1');
        await insertFolder('user1-folder', ownerKey: 'user-1');
        // A brand new guest note was then created before user-2 logged in.
        await insertNote('guest-note');

        final service = ClaimService(database);
        final claimed = await service.claimGuestData('user-2');

        // Only the guest row is claimed -- user-1's rows are untouched.
        expect(claimed, 1);

        final user1Note = await readNote('user1-note');
        expect(user1Note.ownerKey, 'user-1');
        expect(user1Note.pendingSync, isFalse);

        final user1Folder = await readFolder('user1-folder');
        expect(user1Folder.ownerKey, 'user-1');
        expect(user1Folder.pendingSync, isFalse);

        final guestNote = await readNote('guest-note');
        expect(guestNote.ownerKey, 'user-2');
        expect(guestNote.pendingSync, isTrue);
      },
    );
  });
}
