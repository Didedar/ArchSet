# Conflict Detection and Note Forking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the same note is edited from two places between syncs, both versions survive. Detection uses the server-assigned `revision` counter, never device clocks.

**Architecture:** The client sends the `base_revision` each row was edited from. The server accepts a write only if that matches the row's current `revision`, then increments it. A mismatch means someone else got there first: the server keeps its version and names the row in the response, and the client forks its own copy into a new note. Folders and artifacts take the server's version instead of forking.

**Tech Stack:** FastAPI, SQLAlchemy 2.0, Pydantic v2, Postgres; Flutter + drift.

**Spec:** `docs/superpowers/specs/2026-08-02-collaborative-dig-sites-design.md`, section 2.
**Depends on:** `docs/superpowers/plans/2026-08-02-revisions-schema.md` (columns must exist and be deployed).

---

## Correction to the spec

Spec section 2 says a conflict is an HTTP `409`. That is wrong for this endpoint
and the plan does not implement it that way.

`/sync` is a **batch**: one request carries every dirty row. A 409 status
describes the whole response, so it cannot say "notes 3 and 7 conflicted, the
other fifteen were fine". Rejecting the entire batch because one row lost a race
would strand fifteen good rows.

Conflicts are therefore reported **per item inside a 200 response**:
`SyncResponse.conflicted_note_ids`. Only notes need this signal — folders and
artifacts resolve last-write-wins, and "the server won" is indistinguishable
from "the server changed", which the existing response already conveys.

## The trap this design has to avoid

`SyncService._clearPendingNotes` (`lib/data/services/sync_service.dart:313`)
clears `pendingSync` for every row it just pushed. A conflicted row was
**not accepted** — clearing its flag would drop the user's edit silently, which
is the exact failure this whole feature exists to prevent. Conflicted ids must
be excluded from that call.

## File structure

| File | Responsibility |
|---|---|
| `backend/app/schemas/note.py` | **Modify.** `base_revision` in, `revision` + `conflicted_note_ids` out |
| `backend/app/schemas/folder.py`, `artifact.py` | **Modify.** `base_revision` in, `revision` out |
| `backend/app/services/sync_service.py` | **Modify.** Guard writes on revision; increment |
| `backend/app/routers/sync.py` | **Modify.** Thread conflicted ids into the response |
| `lib/data/services/sync_service.dart` | **Modify.** Send base, store revision, honour conflicts |
| `lib/data/repository/notes_repository.dart` | **Modify.** `forkNote` |
| `test/data/repository/notes_repository_test.dart` | **Modify.** Fork behaviour |
| `test/data/services/sync_service_test.dart` | **Modify.** Protocol + conflict handling |

---

## Task 1: Server guards writes on `base_revision`

**Files:**
- Modify: `backend/app/schemas/note.py`, `backend/app/schemas/folder.py`, `backend/app/schemas/artifact.py`, `backend/app/services/sync_service.py`, `backend/app/routers/sync.py`

- [ ] **Step 1: Accept `base_revision` on every sync item**

In `backend/app/schemas/note.py`, add to `NoteSyncItem`:

```python
    # The revision the client based this edit on. None means "I have never
    # synced this row" (a new note) or "I am an old client that does not know
    # about revisions" -- both fall through to the previous last-write-wins
    # behaviour so existing installs keep working.
    base_revision: Optional[int] = None
```

Add the identical field to `FolderSyncItem` in `backend/app/schemas/folder.py`
and to `ArtifactSyncItem` and `ArtifactCommentSyncItem` in
`backend/app/schemas/artifact.py`.

- [ ] **Step 2: Return `revision` on every response item**

Add to `NoteResponse`, `FolderResponse`, `ArtifactResponse` and
`ArtifactCommentResponse`:

```python
    revision: int = 1
```

- [ ] **Step 3: Report conflicted notes**

Add to `SyncResponse` in `backend/app/schemas/note.py`:

```python
    # Notes whose base_revision did not match the server's current revision.
    # Their server-side version is included in `notes` above; the client keeps
    # that under the original id and forks its own copy. Per-item rather than
    # an HTTP 409 because this endpoint is a batch -- one lost race must not
    # reject every other row in the request.
    conflicted_note_ids: List[str] = []
```

- [ ] **Step 4: Write the failing test**

Add to the backend sync tests (find the existing sync test module with
`rg -l "sync_notes" backend/tests`). Follow that file's fixtures:

```python
@pytest.mark.asyncio
async def test_stale_base_revision_is_rejected_and_reported(db_session, test_user):
    """A second device editing from an old revision must not overwrite."""
    service = SyncService(db_session)

    # Device A creates the note and the server stamps revision 1.
    await service.sync_notes(
        user=test_user,
        client_notes=[NoteSyncItem(
            id="n1", title="Layer 2", content="A",
            date=datetime(2026, 8, 2), updated_at=datetime(2026, 8, 2, 10, 0),
        )],
        last_sync_at=None,
    )
    await db_session.flush()

    # Device A edits again from revision 1 -- accepted, revision becomes 2.
    await service.sync_notes(
        user=test_user,
        client_notes=[NoteSyncItem(
            id="n1", title="Layer 2 revised", content="A2",
            date=datetime(2026, 8, 2), updated_at=datetime(2026, 8, 2, 11, 0),
            base_revision=1,
        )],
        last_sync_at=None,
    )
    await db_session.flush()

    # Device B was offline and still thinks the note is at revision 1.
    conflicts = await service.sync_notes(
        user=test_user,
        client_notes=[NoteSyncItem(
            id="n1", title="Layer 2 from device B", content="B",
            date=datetime(2026, 8, 2), updated_at=datetime(2026, 8, 2, 12, 0),
            base_revision=1,
        )],
        last_sync_at=None,
    )
    await db_session.flush()

    note = await db_session.get(Note, "n1")
    # Device B's later timestamp must NOT win: it edited from a stale base.
    assert note.title == "Layer 2 revised"
    assert note.revision == 2
    assert "n1" in conflicts
```

`sync_notes` currently returns only the changed rows, so it needs to return the
conflicted ids too. Change its return type to a tuple
`(changed_rows, conflicted_ids)` and update `routers/sync.py` accordingly —
adjust the test above to match whichever shape you settle on, and say which in
your report.

- [ ] **Step 5: Run it and watch it fail**

```bash
cd backend && source venv/bin/activate && python -m pytest -q -k stale_base_revision
```

**If the suite cannot even load** (`ModuleNotFoundError: llama_index...`), that
is a known broken dev environment, unrelated to this work. Fix it first — see
the "Fix broken backend test/dev environment" task — or this plan cannot be
verified at all. Do not proceed on an unverifiable backend.

- [ ] **Step 6: Implement the guard**

In `backend/app/services/sync_service.py`, inside the `if existing_note:` branch
of `sync_notes`, replace the `if client_note.updated_at > existing_note.updated_at:`
condition with:

```python
                stale = (
                    client_note.base_revision is not None
                    and client_note.base_revision != existing_note.revision
                )
                if stale:
                    # Someone else wrote to this row since the client last saw
                    # it. Keep the server's version and let the client fork.
                    # Deliberately checked before the timestamp comparison: a
                    # device whose clock runs fast would otherwise win a race
                    # it lost.
                    conflicted_ids.append(client_note.id)
                elif (
                    client_note.base_revision is not None
                    or client_note.updated_at > existing_note.updated_at
                ):
                    ... existing field assignments ...
                    existing_note.revision = existing_note.revision + 1
```

Initialise `conflicted_ids: list[str] = []` at the top of the method and return
it alongside the changed rows.

New notes (`else` branch) are created with `revision=1` — the column default
already does this, so no change is needed there.

- [ ] **Step 7: Force conflicted rows into the response**

A conflicted note may not have changed since `last_sync_at`, in which case the
existing "changed since" query will not return it and the client would have no
server version to keep. After the changed-rows query, union in the conflicted
rows explicitly. Add a comment saying why.

- [ ] **Step 8: Apply the same guard to folders, artifacts and comments**

Same `stale` check, but on a mismatch **skip the write silently** — no
conflicted-id list. Spec section 2: folders and artifacts resolve
last-write-wins because forking a dig site would produce two dig sites, and
forking an artifact would double-count a physical find on the map.

- [ ] **Step 9: Run the tests**

```bash
cd backend && source venv/bin/activate && python -m pytest -q
```
Expected: the new test passes and nothing else regresses. Confirm at least one
existing test covers a sync from a client that sends **no** `base_revision`, so
backward compatibility is proven rather than assumed. If none exists, add one.

- [ ] **Step 10: Commit**

```bash
git add backend/app/schemas backend/app/services/sync_service.py backend/app/routers/sync.py backend/tests
git commit -m "feat(backend): reject writes based on a stale revision

Guards each sync write on the base_revision the client edited from. A mismatch
means someone else wrote first, so the server keeps its version and names the
note in conflicted_note_ids.

Checked before the updated_at comparison on purpose: two phones offline in the
field drift apart, and a fast clock would otherwise win a race it lost.

Reported per item inside a 200 rather than as an HTTP 409 -- /sync is a batch,
and one lost race must not reject every other row in the request. Clients that
send no base_revision keep the previous last-write-wins behaviour."
```

---

## Task 2: Client sends `baseRevision` and stores what comes back

**Files:**
- Modify: `lib/data/services/sync_service.dart`
- Test: `test/data/services/sync_service_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/data/services/sync_service_test.dart`, following the existing fixtures:

```dart
  test('sends the baseRevision each row was edited from', () async {
    await database.into(database.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        title: 'Слой 2',
        content: '',
        date: DateTime(2026, 8, 2),
        ownerKey: const Value('u1'),
        pendingSync: const Value(true),
        baseRevision: const Value(4),
      ),
    );

    await service.sync();

    final sent = capturedRequestBody['notes'] as List;
    expect(sent.single['base_revision'], 4);
  });

  test('stores the revision the server assigned', () async {
    // Server echoes the note back at revision 5.
    ...
    final saved = await (database.select(database.notes)
          ..where((t) => t.id.equals('n1')))
        .getSingle();
    expect(saved.baseRevision, 5);
  });
```

Read the existing test file first: it already has a fake HTTP client and a
captured-request mechanism. Use those rather than inventing new ones, and name
the actual helper in your report.

- [ ] **Step 2: Run and watch fail**

```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
flutter test test/data/services/sync_service_test.dart --concurrency=1
```

- [ ] **Step 3: Send it**

In `_noteToSyncMap` (`lib/data/services/sync_service.dart:299`) and the folder /
artifact / comment equivalents, add:

```dart
    'base_revision': note.baseRevision,
```

- [ ] **Step 4: Store what comes back**

In `_applyServerChanges` and `_applyServerArtifactChanges`, set
`baseRevision: Value(data['revision'] as int?)` on every write, so the next edit
is based on the revision the server actually holds.

- [ ] **Step 5: Run the tests, then commit**

```bash
flutter test test/data/services/sync_service_test.dart --concurrency=1
git add lib/data/services/sync_service.dart test/data/services/sync_service_test.dart
git commit -m "feat(sync): exchange row revisions with the server"
```

---

## Task 3: Fork a conflicted note instead of losing it

**Files:**
- Modify: `lib/data/repository/notes_repository.dart`, `lib/data/services/sync_service.dart`
- Test: `test/data/repository/notes_repository_test.dart`, `test/data/services/sync_service_test.dart`

- [ ] **Step 1: Write the failing repository test**

```dart
    test('forkNote keeps both versions with distinct ids', () async {
      ownerHolder.value = 'me';
      await repository.insertNote(note('n1', title: 'Раскоп 3'));

      final fork = await repository.forkNote('n1', at: DateTime(2026, 8, 2, 19, 42));

      final all = await repository.watchAllNotes().first;
      expect(all, hasLength(2));
      expect(fork.id, isNot('n1'));
      // The fork is the local edit, so it still has to be pushed.
      expect(fork.pendingSync, isTrue);
      // ...and it is not based on any server revision, so it uploads as new.
      expect(fork.baseRevision, isNull);
      expect(fork.title, contains('Раскоп 3'));
    });
```

- [ ] **Step 2: Implement `forkNote`**

In `lib/data/repository/notes_repository.dart`:

```dart
  /// Copies [id]'s current local state into a brand-new note, so a version
  /// the server rejected survives instead of being overwritten by it.
  ///
  /// [at] is passed in rather than read from the clock so the label is
  /// testable. The new row has no `baseRevision`: it has never been to the
  /// server, so it uploads as a create rather than racing again.
  Future<Note> forkNote(String id, {required DateTime at}) async {
    final original = await getNoteById(id);
    if (original == null) {
      throw StateError('cannot fork a note that does not exist: $id');
    }

    final label = '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final fork = original.copyWith(
      id: const Uuid().v4(),
      title: '${original.title} (версия $label)',
    );

    await database.into(database.notes).insert(
      NotesCompanion.insert(
        id: fork.id,
        title: fork.title,
        content: fork.content,
        date: fork.date,
        audioPath: Value(fork.audioPath),
        folderId: Value(fork.folderId),
        updatedAt: Value(at),
        pendingSync: const Value(true),
        isDeleted: const Value(false),
        ownerKey: Value(_owner.value),
        baseRevision: const Value(null),
      ),
    );

    return fork;
  }
```

The fork label is time-only for now; it gains the author's name when folders can
be shared and there is someone else to name.

- [ ] **Step 3: Fork on conflict during sync**

In `lib/data/services/sync_service.dart`, after the push:

```dart
      final conflicted =
          ((response['conflicted_note_ids'] as List?) ?? const [])
              .cast<String>()
              .toSet();

      // Fork BEFORE clearing dirty flags and BEFORE applying server changes:
      // the fork has to copy the local edit while it is still the local edit.
      for (final id in conflicted) {
        await _notesRepository.forkNote(id, at: DateTime.now());
      }
```

- [ ] **Step 4: Do not clear the dirty flag on rows the server refused**

This is the step that decides whether the feature loses data. `_clearPendingNotes`
clears `pendingSync` for everything pushed; a conflicted row was **not** accepted,
so clearing it would silently drop the user's edit.

Pass the conflicted set in and skip those ids:

```dart
      await _clearPendingNotes(
        localNotes.where((n) => !conflicted.contains(n.id)).toList(),
      );
```

- [ ] **Step 5: Write the test that proves Step 4**

```dart
  test('a conflicted note keeps its dirty flag and gains a fork', () async {
    // server responds with conflicted_note_ids: ['n1']
    ...
    final rows = await database.select(database.notes).get();
    expect(rows, hasLength(2), reason: 'original plus fork');
    final fork = rows.firstWhere((r) => r.id != 'n1');
    expect(fork.pendingSync, isTrue);
    expect(fork.baseRevision, isNull);
  });
```

- [ ] **Step 6: Mutation-test both halves**

A test that cannot fail is worthless, and these two are the whole feature:

1. Make `forkNote` a no-op → the conflict test must fail.
2. Restore. Remove the `.where(...)` filter in Step 4 → assert a test fails.

If either survives, the test is not testing what it claims. Report both outcomes.

- [ ] **Step 7: Full suite and commit**

```bash
flutter test --concurrency=1
flutter analyze
```

Known pre-existing failures, not yours: `audio_bloc_test.dart` "segment
management" (timing flake, ~1 in 3, fails in isolation too) and
`composition_root_test.dart` (`MissingPluginException`, deterministic). Anything
else is a regression.

```bash
git add lib test
git commit -m "feat(sync): fork a note the server refused instead of losing it"
```

---

## Deployment order

Both halves of the schema plan must already be live:

1. `alembic stamp 0001` then `alembic upgrade head` on production
2. Deploy the backend from this plan
3. Release the client

An old client against the new backend is fine — it sends no `base_revision` and
gets the previous last-write-wins behaviour. A new client against an old backend
is **not**: it would send `base_revision`, have it ignored, and store `revision`
as null. Ship the backend first.
