# Shared Dig Sites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two archaeologists share a folder — a dig site — and both see and edit everything inside it, offline all day, merging when signal returns.

**Architecture:** A `folder_members` table makes a folder reachable by someone who does not own it. Every read and write derives from **one** access predicate rather than twenty hand-edited conditions. On the client, `ownerKey` keeps its current meaning (whose local replica a row is) and a new `authorId` records who wrote it — that separation is what lets sharing land without touching the code that prevents cross-account leaks.

**Tech Stack:** FastAPI, SQLAlchemy 2.0, Alembic, Postgres; Flutter + drift + flutter_bloc.

**Spec:** `docs/superpowers/specs/2026-08-02-collaborative-dig-sites-design.md`, sections 1, 3, 4, 5.
**Depends on:** the revision plans — conflict handling must already work, or sharing just multiplies the ways to lose an edit.

---

## The risk this plan is mostly about

`rg -c "user_id == "` counts **20 sites** across `app/routers/{notes,folders}.py` and
`app/services/sync_service.py` where `user_id == current_user.id` is what stops
one account reading another's data. Sharing means every one of them becomes
"owner **or** member".

This project has already shipped that bug once — the `ownerKey` work exists
because notes leaked between accounts on a shared device. Twenty independent
edits is twenty chances to repeat it.

So the spine of this plan is a **single** access helper. Adding a table is easy;
the discipline is that no query is allowed to spell the rule out for itself.

## Phase split

**Phase A (Tasks 1-5, backend)** is independently deployable and testable
through the API: membership, access control, invitations. No client change.
**Phase B (Tasks 6-9, client)** makes it usable.

Ship and verify A before starting B — a leak found through an HTTP test is
cheap, the same leak found through the UI is not.

---

# Phase A — backend

## Task 1: The `folder_members` table

**Files:**
- Create: `backend/app/models/membership.py`, `backend/alembic/versions/0003_folder_members.py`
- Modify: `backend/app/models/__init__.py`

- [ ] **Step 1: Define the model**

Create `backend/app/models/membership.py`:

```python
"""Folder membership: who, besides the owner, can reach a dig site."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class FolderMember(Base):
    """A user granted access to a folder they do not own.

    The owner is NOT represented here -- ownership stays on `folders.user_id`.
    Access is "owner OR row in this table", expressed once in
    `app/utils/access.py` and nowhere else.
    """

    __tablename__ = "folder_members"

    folder_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("folders.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=datetime.utcnow
    )
```

The composite primary key makes a duplicate invitation a no-op rather than a
second row, and `ON DELETE CASCADE` means deleting a folder or a user cleans up
its memberships without an orphan sweep.

- [ ] **Step 2: Export it**

In `backend/app/models/__init__.py`:

```python
from .membership import FolderMember
```
and add `"FolderMember"` to `__all__`.

The Alembic `env.py` imports this package, so the new table is only visible to
autogenerate once it is exported here.

- [ ] **Step 3: Generate and read the migration**

```bash
cd backend && source venv/bin/activate
createdb archset_baseline_tmp 2>/dev/null || true
export MIG_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/archset_baseline_tmp"
DATABASE_URL="$MIG_URL" alembic upgrade head
DATABASE_URL="$MIG_URL" alembic revision --autogenerate -m "folder members" --rev-id 0003
```

Read the generated file. It must contain exactly one `op.create_table('folder_members')`
with both foreign keys and `ondelete='CASCADE'`. Nothing else.

- [ ] **Step 4: Verify it round-trips**

```bash
DATABASE_URL="$MIG_URL" alembic upgrade head && DATABASE_URL="$MIG_URL" alembic current
DATABASE_URL="$MIG_URL" alembic downgrade -1
DATABASE_URL="$MIG_URL" alembic upgrade head
DATABASE_URL="$MIG_URL" alembic revision --autogenerate -m "drift" --rev-id tmpd
```
The drift file's `upgrade()` must be `pass`. Delete it, then `dropdb archset_baseline_tmp`.

- [ ] **Step 5: Commit**

```bash
git add backend/app/models backend/alembic/versions
git commit -m "feat(backend): add folder_members table

Makes a folder reachable by someone who does not own it. Ownership stays on
folders.user_id; this table is only the additional grants."
```

---

## Task 2: One access predicate, used everywhere

The security spine. Write it once, test it hard, then make every query use it.

**Files:**
- Create: `backend/app/utils/access.py`, `backend/tests/utils/test_access.py`

- [ ] **Step 1: Write the failing tests first**

Create `backend/tests/utils/test_access.py`:

```python
"""The single access rule. Every read and write in the app derives from this,
so a hole here is a hole everywhere -- which is why it is tested directly and
not only through the endpoints that use it."""

import pytest

from app.models.folder import Folder
from app.models.membership import FolderMember
from app.utils.access import accessible_folder_ids


@pytest.mark.asyncio
async def test_an_owner_reaches_their_own_folder(db_session, test_user):
    db_session.add(Folder(id="f1", user_id=test_user.id, name="Trench 3",
                          color="#E8B731"))
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == {"f1"}


@pytest.mark.asyncio
async def test_a_member_reaches_a_folder_they_do_not_own(
    db_session, test_user, other_user
):
    db_session.add(Folder(id="f1", user_id=other_user.id, name="Trench 3",
                          color="#E8B731"))
    db_session.add(FolderMember(folder_id="f1", user_id=test_user.id))
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == {"f1"}


@pytest.mark.asyncio
async def test_a_stranger_reaches_nothing(db_session, test_user, other_user):
    db_session.add(Folder(id="f1", user_id=other_user.id, name="Trench 3",
                          color="#E8B731"))
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == set()


@pytest.mark.asyncio
async def test_a_revoked_member_reaches_nothing(
    db_session, test_user, other_user
):
    db_session.add(Folder(id="f1", user_id=other_user.id, name="Trench 3",
                          color="#E8B731"))
    membership = FolderMember(folder_id="f1", user_id=test_user.id)
    db_session.add(membership)
    await db_session.flush()
    await db_session.delete(membership)
    await db_session.flush()

    assert await accessible_folder_ids(db_session, test_user) == set()
```

`other_user` may not exist as a fixture. Check `backend/tests/conftest.py`; if
it does not, add one mirroring `test_user` with a different id and email, and
say so in your report.

- [ ] **Step 2: Run and watch fail**

```bash
cd backend && source venv/bin/activate && python -m pytest -q tests/utils/test_access.py
```
Expected: import error — `app.utils.access` does not exist.

- [ ] **Step 3: Implement**

Create `backend/app/utils/access.py`:

```python
"""The one place that answers "what can this user reach?".

Sharing turns roughly twenty `user_id == current_user.id` conditions into
"owner or member". Twenty hand-edited conditions is twenty chances to get it
wrong, and this project has already shipped a cross-account leak once. So the
rule is written here and imported, never restated.
"""

from typing import Set

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.folder import Folder
from ..models.membership import FolderMember
from ..models.user import User


async def accessible_folder_ids(db: AsyncSession, user: User) -> Set[str]:
    """Every folder id `user` may read or write: owned plus shared with them."""
    owned = await db.execute(select(Folder.id).where(Folder.user_id == user.id))
    shared = await db.execute(
        select(FolderMember.folder_id).where(FolderMember.user_id == user.id)
    )
    return set(owned.scalars().all()) | set(shared.scalars().all())
```

- [ ] **Step 4: Green, then commit**

```bash
python -m pytest -q tests/utils/test_access.py
git add backend/app/utils/access.py backend/tests/utils
git commit -m "feat(backend): add the single folder-access rule"
```

---

## Task 3: Route every query through it

**Files:**
- Modify: `backend/app/routers/notes.py`, `backend/app/routers/folders.py`, `backend/app/services/sync_service.py`

- [ ] **Step 1: Write the leak test first**

This is the test that matters most in the plan. Add to
`backend/tests/routers/test_sync.py` (match its existing client fixtures):

```python
@pytest.mark.asyncio
async def test_a_non_member_never_receives_a_shared_folders_notes(
    client, db_session, test_user, other_user, auth_headers_for
):
    """The cross-account leak, in its new shape.

    other_user owns a dig site and a note in it. test_user is NOT a member.
    Nothing test_user does may surface that note.
    """
    db_session.add(Folder(id="f1", user_id=other_user.id, name="Trench 3",
                          color="#E8B731"))
    db_session.add(Note(id="n1", user_id=other_user.id, folder_id="f1",
                        title="Layer 2", content="secret",
                        date=datetime.utcnow(), updated_at=datetime.utcnow()))
    await db_session.commit()

    response = await client.post(
        "/api/v1/sync",
        json={"notes": [], "folders": [], "last_sync_at": None},
        headers=auth_headers_for(test_user),
    )

    assert response.status_code == 200
    body = response.json()
    assert [n["id"] for n in body["notes"]] == []
    assert [f["id"] for f in body["folders"]] == []


@pytest.mark.asyncio
async def test_a_member_does_receive_them(
    client, db_session, test_user, other_user, auth_headers_for
):
    db_session.add(Folder(id="f1", user_id=other_user.id, name="Trench 3",
                          color="#E8B731"))
    db_session.add(Note(id="n1", user_id=other_user.id, folder_id="f1",
                        title="Layer 2", content="shared",
                        date=datetime.utcnow(), updated_at=datetime.utcnow()))
    db_session.add(FolderMember(folder_id="f1", user_id=test_user.id))
    await db_session.commit()

    response = await client.post(
        "/api/v1/sync",
        json={"notes": [], "folders": [], "last_sync_at": None},
        headers=auth_headers_for(test_user),
    )

    assert [n["id"] for n in response.json()["notes"]] == ["n1"]
```

- [ ] **Step 2: Run; the second must fail, the first must pass**

The first passing already is expected — today nothing is shared, so nothing
leaks. It is there to stay passing forever.

- [ ] **Step 3: Replace the conditions**

For **folders**, wherever `Folder.user_id == user.id` gates a read:

```python
    accessible = await accessible_folder_ids(db, user)
    query = select(Folder).where(Folder.id.in_(accessible))
```

For **notes**:

```python
    # A note is reachable if the user wrote it, or if it sits in a folder they
    # can reach. Unfiled notes (folder_id IS NULL) are private by design --
    # spec section 1 -- so they match only via the first arm.
    query = select(Note).where(
        or_(Note.user_id == user.id, Note.folder_id.in_(accessible))
    )
```

For **artifacts**, reachable through their note:

```python
    reachable_note_ids = select(Note.id).where(
        or_(Note.user_id == user.id, Note.folder_id.in_(accessible))
    )
    query = select(Artifact).where(
        or_(Artifact.user_id == user.id,
            Artifact.note_id.in_(reachable_note_ids))
    )
```

For **artifact comments**, through their artifact:

```python
    reachable_artifact_ids = select(Artifact.id).where(
        or_(Artifact.user_id == user.id,
            Artifact.note_id.in_(reachable_note_ids))
    )
    query = select(ArtifactComment).where(
        or_(ArtifactComment.user_id == user.id,
            ArtifactComment.artifact_id.in_(reachable_artifact_ids))
    )
```

Apply the same predicate to the **write** paths (the `existing_*` prefetch
queries in `sync_service.py`), not only the reads. A member must be able to
edit, and a stranger must not — reads and writes have to agree.

- [ ] **Step 4: Prove no site was missed**

```bash
cd backend && rg -n "user_id == (current_user|user)\.id" app/routers app/services
```

Every surviving hit must be one of: creating a row (stamping ownership),
an ownership check for invite/revoke, or the first arm of an `or_` above.
**List every remaining hit in your report with its justification.** A silent
leftover is exactly how the first leak happened.

- [ ] **Step 5: Full suite, then commit**

```bash
python -m pytest -q
```
Expected: 145 baseline plus the new tests, no regressions.

```bash
git commit -m "feat(backend): let folder members reach a shared dig site

Every read and write now derives from accessible_folder_ids() instead of
restating owner-only access. Unfiled notes stay private: they have no folder
to be shared through."
```

---

## Task 4: Invite and revoke

**Files:**
- Create: `backend/app/routers/members.py`, `backend/tests/routers/test_members.py`
- Modify: `backend/app/main.py`, `backend/app/schemas/folder.py`

- [ ] **Step 1: Write the failing tests**

```python
@pytest.mark.asyncio
async def test_the_owner_can_invite_by_email(client, db_session, test_user,
                                             other_user, auth_headers_for):
    db_session.add(Folder(id="f1", user_id=test_user.id, name="Trench 3",
                          color="#E8B731"))
    await db_session.commit()

    response = await client.post(
        "/api/v1/folders/f1/members",
        json={"email": other_user.email},
        headers=auth_headers_for(test_user),
    )

    assert response.status_code == 201


@pytest.mark.asyncio
async def test_a_member_cannot_invite_others(client, db_session, test_user,
                                             other_user, third_user,
                                             auth_headers_for):
    """Only the owner grows the team -- spec: the owner is the one thing that
    distinguishes them from a member."""
    db_session.add(Folder(id="f1", user_id=other_user.id, name="Trench 3",
                          color="#E8B731"))
    db_session.add(FolderMember(folder_id="f1", user_id=test_user.id))
    await db_session.commit()

    response = await client.post(
        "/api/v1/folders/f1/members",
        json={"email": third_user.email},
        headers=auth_headers_for(test_user),
    )

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_inviting_an_unknown_email_is_a_clear_404(
    client, db_session, test_user, auth_headers_for
):
    db_session.add(Folder(id="f1", user_id=test_user.id, name="Trench 3",
                          color="#E8B731"))
    await db_session.commit()

    response = await client.post(
        "/api/v1/folders/f1/members",
        json={"email": "nobody@example.com"},
        headers=auth_headers_for(test_user),
    )

    assert response.status_code == 404


@pytest.mark.asyncio
async def test_inviting_twice_is_idempotent(client, db_session, test_user,
                                            other_user, auth_headers_for):
    db_session.add(Folder(id="f1", user_id=test_user.id, name="Trench 3",
                          color="#E8B731"))
    await db_session.commit()
    body = {"email": other_user.email}
    headers = auth_headers_for(test_user)

    await client.post("/api/v1/folders/f1/members", json=body, headers=headers)
    second = await client.post("/api/v1/folders/f1/members", json=body,
                               headers=headers)

    assert second.status_code in (200, 201)
    listed = await client.get("/api/v1/folders/f1/members", headers=headers)
    assert len(listed.json()) == 1
```

- [ ] **Step 2: Implement the router**

Create `backend/app/routers/members.py` with:

- `GET /folders/{folder_id}/members` — owner or member may list.
- `POST /folders/{folder_id}/members` — **owner only**, body `{"email": str}`.
  `404` if no user has that email; upsert so a repeat is idempotent; `201`.
- `DELETE /folders/{folder_id}/members/{user_id}` — **owner only**; `204`.

Inviting yourself when you already own the folder must not create a row —
ownership is not a membership.

Register the router in `backend/app/main.py` next to the others.

- [ ] **Step 3: Green, full suite, commit**

```bash
python -m pytest -q
git commit -m "feat(backend): invite and revoke dig-site members"
```

---

## Task 5: Revoking must not destroy the other person's work

Spec section 4. This is a behaviour test, not a feature — write it now so the
client half is built against a server that already behaves correctly.

- [ ] **Step 1: The test**

```python
@pytest.mark.asyncio
async def test_revoking_access_leaves_the_members_notes_on_the_server(
    client, db_session, test_user, other_user, auth_headers_for
):
    """Losing access must not delete what someone wrote. The rows stay; they
    simply stop being reachable through the folder."""
    db_session.add(Folder(id="f1", user_id=test_user.id, name="Trench 3",
                          color="#E8B731"))
    db_session.add(FolderMember(folder_id="f1", user_id=other_user.id))
    db_session.add(Note(id="n1", user_id=other_user.id, folder_id="f1",
                        title="Layer 2", content="their work",
                        date=datetime.utcnow(), updated_at=datetime.utcnow()))
    await db_session.commit()

    await client.delete(
        f"/api/v1/folders/f1/members/{other_user.id}",
        headers=auth_headers_for(test_user),
    )

    note = await db_session.get(Note, "n1")
    assert note is not None, "revoking access must never delete a note"
    assert note.content == "their work"
```

- [ ] **Step 2: Make it pass, then commit**

`ON DELETE CASCADE` is on `folder_members`, not on notes, so this should already
hold. Confirm it does rather than assuming — and if it does, say so in your
report instead of adding code.

---

# Phase B — client

## Task 6: Schema v11 — `authorId` and `isShared`

**Files:**
- Modify: `lib/data/database/app_database.dart`, `lib/data/repository/notes_repository.dart`
- Test: `test/data/database/app_database_migration_test.dart`

- [ ] **Step 1: Write the migration test**

Mirror the existing `buildV9Database` / v9→v10 test with a `buildV10Database`
and a v10→v11 case asserting rows survive and both new columns default to
null/false.

- [ ] **Step 2: Add the columns**

To `Notes`, `ImageMetadata` and `ArtifactComments`:

```dart
  /// Who wrote this row. Distinct from `ownerKey`, which says whose local
  /// replica it is: in a shared folder those differ, and conflating them is
  /// what would let one account's rows render as another's.
  TextColumn get authorId => text().nullable()();
```

To `Folders`, both of the above plus:

```dart
  /// True when this folder has members beyond its owner. Display only -- the
  /// server remains the authority on who may actually read it.
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
```

Bump `schemaVersion` to 11 and add the `if (from < 11)` block. **Guard each
`addColumn` the same way v10 does** — `createTable` earlier in the same upgrade
run already produces the current schema, and without the guards a v6 database
fails with "duplicate column name".

- [ ] **Step 3: Stamp `authorId` on write**

In `NotesRepository`, every write that already sets `ownerKey: Value(_owner.value)`
also sets `authorId: Value(_owner.value)`. They are equal today and diverge only
when a shared folder brings in someone else's rows.

- [ ] **Step 4: Regenerate, test, commit**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test --concurrency=1
```

---

## Task 7: Sync carries authorship and sharing

**Files:**
- Modify: `lib/data/services/sync_service.dart`

- [ ] Send `author_id` in each sync map; store `authorId` from the server
      response in `_applyServerChanges` and `_applyServerArtifactChanges`,
      alongside the `baseRevision` handling already there.
- [ ] Keep stamping `ownerKey: Value(ownerId)` on applied rows — unchanged and
      load-bearing. A row from a colleague lands in *this* device's replica for
      *this* account; that is exactly what `ownerKey` means and what keeps a
      second account on the same phone from seeing it.
- [ ] Test: a note authored by someone else round-trips with
      `authorId != ownerKey`, and is still invisible to a different local
      account. **That second assertion is the leak test** — write it.

---

## Task 8: Members screen and invitations

**Files:**
- Modify: `lib/data/services/api_service.dart`, `lib/core/localization/app_strings.dart`
- Create: `lib/presentation/members/` (bloc + page, following `artifacts/` layout)

- [ ] API client methods for list / invite / revoke.
- [ ] Members page: list, "Invite" (email field), "Remove" for the owner only.
- [ ] All new strings in **four** locales — `app_strings_test.dart` fails loudly
      otherwise, which is the point.
- [ ] Errors must be legible, not raw: "no account with that email" for the
      404, and an offline attempt must say invitations need a connection rather
      than failing silently.

---

## Task 9: Make sharing visible

**Files:**
- Modify: `lib/presentation/notes/pages/notes_page.dart`, `lib/presentation/editor/pages/diary_edit_page.dart`, `lib/presentation/pages/settings_page.dart`

- [ ] Shared folders show a badge in the folder list.
- [ ] A note whose `authorId` differs from the current owner shows "author: …".
- [ ] A conflict fork shows a banner explaining that a colleague edited the same
      note, with a link to the other version. Without it, two near-identical
      notes read as a bug.
- [ ] **Guests:** the sharing entry point is visible but locked — "requires an
      account" plus the sign-in button already built into settings. Membership
      needs a `user_id`; a guest has none. Test this.

---

## Task 10: Losing access must not strand the member's own work

Spec section 4, client half. Task 5 proved the server keeps the rows; this is
what the person who lost access actually sees.

**Files:**
- Modify: `lib/data/services/sync_service.dart`, `lib/data/repository/notes_repository.dart`
- Test: `test/data/services/sync_service_test.dart`

The state this fixes is genuinely odd, so it is worth stating plainly. After a
revoke, the access predicate still reaches her notes through the first arm —
`Note.user_id == user.id` — because **she wrote them**. What she loses is the
folder. So her notes survive but point at a folder she can no longer see: they
vanish from the folder list and appear nowhere else.

- [ ] **Step 1: Write the failing test**

```dart
    test('notes in a folder that is no longer shared become personal notes',
        () async {
      // She authored these inside the shared dig site.
      await insertNote('n1', pendingSync: false);
      await (database.update(database.notes)..where((t) => t.id.equals('n1')))
          .write(const NotesCompanion(folderId: Value('f1')));
      await database.into(database.folders).insert(
            FoldersCompanion.insert(
              id: 'f1',
              name: 'Раскоп 3',
              createdAt: DateTime(2026, 8, 2),
              ownerKey: const Value(ownerId),
            ),
          );

      // The sync no longer carries f1: access was revoked while she was away.
      when(() => apiService.post(any(), any()))
          .thenAnswer((_) async => emptyPullResponse());

      await buildService().sync();

      final note = await (database.select(database.notes)
            ..where((t) => t.id.equals('n1')))
          .getSingle();
      // Detached, not deleted. Someone else's admin action must never destroy
      // her writing.
      expect(note.folderId, isNull);
      expect(note.isDeleted, isFalse);
      expect(note.title, isNotEmpty);
    });
```

- [ ] **Step 2: Implement detachment**

After applying server changes in `sync()`, for folders that were previously
`isShared` and are absent from this pull, detach their notes:

```dart
  /// A folder that stops arriving from the server is one this account can no
  /// longer reach -- access was revoked, or it was deleted by its owner.
  /// Its notes stay: they are this person's own writing, and an admin action
  /// by someone else must never destroy it. They simply stop belonging to a
  /// dig site.
  Future<void> _detachNotesFromUnreachableFolders(
    Set<String> reachableFolderIds,
    String ownerId,
  ) async { ... }
```

Only run this on a **successful** pull. An offline or failed sync returns no
folders either, and detaching on that would silently dismantle a working setup
every time signal dropped — a far worse bug than the one being fixed. Assert
that in a test too.

- [ ] **Step 3: Tell the user rather than letting notes silently move**

Mark detached notes so the UI can show "the dig site is no longer shared with
you". Reuse the existing string mechanism; four locales as always.

- [ ] **Step 4: Mutation-test the guard**

Make the detachment run unconditionally (not just on a successful pull) and
confirm the offline test fails. If it does not, that test is not protecting
anything.

---

## Deployment order

1. `alembic upgrade head` on production (adds `folder_members`)
2. Deploy the backend
3. Release the client

An old client against the new backend is fine: it never asks for members, and
sync returns only what it owns because it has no memberships.

## Out of scope, deliberately

Photo files (still local-only), roles and permissions beyond owner/member,
live co-editing, offline invitations, and storage garbage collection.
