import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archset_r2/data/current_owner_holder.dart';
import 'package:archset_r2/data/database/app_database.dart';
import 'package:archset_r2/data/repository/notes_repository.dart';

/// Signing in while the app is already open.
///
/// A database watch compiles its WHERE clause once, when it is subscribed to,
/// and then re-runs *that* query whenever the tables change. Signing in
/// changes whose rows these are without touching a single table, so a stream
/// opened while the app was a guest went on asking the guest's question
/// forever.
///
/// What the person saw: a diary that stayed empty after they signed in, and
/// -- worse -- entries they created afterwards never appearing either, because
/// those carried an owner the frozen query was not looking for. The rows were
/// on disk the whole time.
void main() {
  late AppDatabase database;
  late CurrentOwnerHolder owner;
  late NotesRepository repository;

  const ivan = 'ivan-id';

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    owner = CurrentOwnerHolder(); // launched as a guest
    repository = NotesRepository(database, ownerHolder: owner);
  });

  tearDown(() async {
    await owner.dispose();
    await database.close();
  });

  Future<void> insertNote(String id, {String? ownerKey}) async {
    await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            title: 'Слой $id',
            content: '',
            date: DateTime(2026, 8, 5),
            ownerKey: Value(ownerKey),
          ),
        );
  }

  Future<void> insertFolder(String id, {String? ownerKey}) async {
    await database
        .into(database.folders)
        .insert(
          FoldersCompanion.insert(
            id: id,
            name: 'Раскоп $id',
            color: const Value('#E8B731'),
            createdAt: DateTime(2026, 8, 5),
            ownerKey: Value(ownerKey),
          ),
        );
  }

  test('entries already on disk appear the moment their account signs in', () async {
    await insertNote('n1', ownerKey: ivan);

    final seen = <List<Note>>[];
    final subscription = repository.watchAllNotes().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    expect(seen.last, isEmpty, reason: 'a guest must not see an account\'s rows');

    owner.value = ivan;
    await pumpEventQueue();

    expect(seen.last.map((n) => n.id), ['n1']);
  });

  test('an entry written after signing in shows up', () async {
    final seen = <List<Note>>[];
    final subscription = repository.watchAllNotes().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    owner.value = ivan;
    await pumpEventQueue();
    await insertNote('n-new', ownerKey: ivan);
    await pumpEventQueue();

    expect(seen.last.map((n) => n.id), ['n-new']);
  });

  test('dig sites follow the same rule', () async {
    await insertFolder('f1', ownerKey: ivan);

    final seen = <List<Folder>>[];
    final subscription = repository.watchAllFolders().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(seen.last, isEmpty);

    owner.value = ivan;
    await pumpEventQueue();

    expect(seen.last.map((f) => f.id), ['f1']);
  });

  test('the counts behind the folder list follow it too', () async {
    await insertNote('n1', ownerKey: ivan);

    final seen = <int>[];
    final subscription = repository.watchAllNotesCount().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(seen.last, 0);

    owner.value = ivan;
    await pumpEventQueue();

    expect(seen.last, 1);
  });

  test('signing out stops showing the account\'s entries', () async {
    await insertNote('n1', ownerKey: ivan);
    owner.value = ivan;

    final seen = <List<Note>>[];
    final subscription = repository.watchAllNotes().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(seen.last, isNotEmpty);

    owner.value = null;
    await pumpEventQueue();

    expect(
      seen.last,
      isEmpty,
      reason: 'a guest must not keep seeing the account that just left',
    );
  });

  test('a re-assignment to the same account does not churn the stream', () async {
    owner.value = ivan;

    final seen = <List<Note>>[];
    final subscription = repository.watchAllNotes().listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    final before = seen.length;

    owner.value = ivan;
    await pumpEventQueue();

    expect(seen.length, before, reason: 'nothing changed, so nothing to re-run');
  });
}
