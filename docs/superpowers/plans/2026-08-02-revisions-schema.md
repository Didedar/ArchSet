# Revisions: Schema Groundwork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the `revision` / `baseRevision` columns in place on both sides, and give the backend a real migration tool — with **zero behaviour change**, so the schema can be deployed and confirmed against production before any sync logic depends on it.

**Architecture:** The backend gains Alembic for schema *alterations*; `create_all` stays as the bootstrap for fresh/test databases. Production adopts Alembic via a one-time `stamp`. The client gains a Drift v9→v10 migration. Nothing reads the new columns yet.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 (asyncpg at runtime, psycopg2 for Alembic), Alembic, Postgres; Flutter + drift.

**Spec:** `docs/superpowers/specs/2026-08-02-collaborative-dig-sites-design.md`, section 1.

---

## Why this is its own plan

The backend has **no migration tooling**: `init_db()` calls `Base.metadata.create_all`
(`backend/app/database.py:44-46`), which creates missing tables but never alters
existing ones — `backend/app/models/note.py:17` says so outright, and
`backend/scripts/add_indexes.sql` exists because of it.

A missing index is slow. A missing **column** is a 500 on every request that
touches it. So the schema change must land and be verified on the live Railway
database *before* any code depends on it. That ordering is the whole reason this
is separated from the conflict-detection work.

## File structure

| File | Responsibility |
|---|---|
| `backend/alembic.ini` | **Create.** Alembic config |
| `backend/alembic/env.py` | **Create.** Wires Alembic to app settings + models |
| `backend/alembic/versions/0001_baseline.py` | **Create.** Snapshot of today's schema |
| `backend/alembic/versions/0002_add_revision.py` | **Create.** Adds `revision` to four tables |
| `backend/app/models/{note,folder,artifact}.py` | **Modify.** Declare `revision` |
| `backend/requirements.txt` | **Modify.** Add `alembic` |
| `backend/README.md` | **Modify.** Document the migration workflow |
| `lib/data/database/app_database.dart` | **Modify.** Four tables + v10 migration |
| `test/data/database/app_database_migration_test.dart` | **Modify.** v9→v10 coverage |

---

## Task 1: Introduce Alembic

**Files:**
- Create: `backend/alembic.ini`, `backend/alembic/env.py`, `backend/alembic/versions/0001_baseline.py`
- Modify: `backend/requirements.txt`, `backend/README.md`

- [ ] **Step 1: Add the dependency**

In `backend/requirements.txt`, under the `# Database` block, after `psycopg2-binary>=2.9.9`:

```
alembic>=1.13.0
```

Install it:

```bash
cd backend && pip install "alembic>=1.13.0"
```

- [ ] **Step 2: Create `backend/alembic.ini`**

```ini
# Alembic owns schema *alterations*. Fresh and test databases are still
# bootstrapped by Base.metadata.create_all() in app/database.py -- see
# backend/README.md for why both exist and how they stay in step.
[alembic]
script_location = alembic
prepend_sys_path = .
version_path_separator = os

# sqlalchemy.url is deliberately absent: env.py reads it from app settings so
# there is exactly one place the database URL is configured.

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

- [ ] **Step 3: Create `backend/alembic/env.py`**

```python
"""Alembic environment.

Runs migrations with the *synchronous* psycopg2 driver even though the app
itself uses asyncpg. Migrations are short, one-shot, and single-threaded, so
async buys nothing here and sync keeps this file simple. psycopg2-binary is
already a dependency.
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.config import settings
from app.database import Base

# Importing the models package registers every table on Base.metadata, which
# is what --autogenerate diffs against. Without this import Alembic would see
# an empty schema and generate a migration that drops everything.
from app import models  # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _sync_url() -> str:
    """The app's URL rewritten for psycopg2."""
    return settings.database_url.replace("+asyncpg", "+psycopg2")


def run_migrations_offline() -> None:
    context.configure(
        url=_sync_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    section = config.get_section(config.config_ini_section) or {}
    section["sqlalchemy.url"] = _sync_url()

    connectable = engine_from_config(
        section,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

- [ ] **Step 4: Create `backend/alembic/script.py.mako`**

```mako
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

revision: str = ${repr(up_revision)}
down_revision: Union[str, None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
```

- [ ] **Step 5: Generate the baseline against a scratch database**

The baseline must describe today's schema. Generate it from the models against
an **empty** database so autogenerate emits `create_table` for everything:

```bash
cd backend
createdb archset_baseline_tmp 2>/dev/null || true
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/archset_baseline_tmp" \
  alembic revision --autogenerate -m "baseline" --rev-id 0001
```

If no local Postgres is available, start the one from `docker-compose.yaml`
first (`docker compose up -d`) and point the URL at it with a scratch database
name.

Rename the generated file to `backend/alembic/versions/0001_baseline.py` if it
is not already named that.

- [ ] **Step 6: Read the generated baseline and confirm it matches reality**

Open the file. It must contain `op.create_table` for `users`, `folders`,
`notes`, `artifacts`, `artifact_comments` and nothing surprising (no dropped
tables, no unexpected renames). Compare column-by-column against
`backend/app/models/`. **Do not skip this** — an autogenerated baseline that
is wrong will make every later migration wrong.

Add this to the top of the file's docstring:

```
Baseline: the schema as it stood before Alembic was introduced. Existing
databases adopt it with `alembic stamp 0001` (which records it as applied
WITHOUT running it). Only a genuinely empty database should ever run this
upgrade.
```

- [ ] **Step 7: Verify round-trip on the scratch database**

```bash
cd backend
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/archset_baseline_tmp" alembic upgrade head
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/archset_baseline_tmp" alembic current
```
Expected: `alembic current` prints `0001 (head)`.

Then confirm autogenerate now sees no drift:
```bash
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/archset_baseline_tmp" \
  alembic revision --autogenerate -m "drift check" --rev-id tmpcheck
```
Open the generated file. `upgrade()` must be `pass`. **Delete that file.** If it
is not empty, the baseline does not match the models — fix it before continuing.

```bash
rm backend/alembic/versions/tmpcheck_drift_check.py
dropdb archset_baseline_tmp
```

- [ ] **Step 8: Document the workflow**

Append to `backend/README.md`:

```markdown
## Database migrations

Two mechanisms, deliberately:

- `Base.metadata.create_all()` in `app/database.py` bootstraps a **fresh** or
  **test** database from the models. It creates missing tables and does nothing
  to existing ones.
- **Alembic** owns every change to a database that already exists — adding a
  column, changing a type, adding a table after the fact. `create_all` cannot
  do any of that, which is why `scripts/add_indexes.sql` had to exist.

Both read the schema from the same SQLAlchemy models, so they cannot disagree
about what the schema *should* be. What they differ on is whether they can get
an existing database there.

### Adopting Alembic on a database that predates it (once, per environment)

```bash
alembic stamp 0001   # record the baseline as applied WITHOUT running it
```

Run this against production **before** the first `alembic upgrade head`.
Skipping it makes Alembic try to `CREATE TABLE users` on a database that
already has it.

### Applying a migration

```bash
alembic upgrade head
```

Run this **before** deploying code that reads the new columns. A missing column
is a 500 on every request that touches it.

### Creating a migration

```bash
alembic revision --autogenerate -m "what changed"
```

Always read the generated file before committing it. Autogenerate does not
detect renames (it emits drop + add, which loses data) and can miss server
defaults.
```

- [ ] **Step 9: Commit**

```bash
git add backend/alembic.ini backend/alembic backend/requirements.txt backend/README.md
git commit -m "build(backend): introduce Alembic for schema migrations

create_all() creates missing tables but never alters existing ones, so every
column added from here on would silently not exist in production -- a 500 on
every request that touched it. scripts/add_indexes.sql was the manual
workaround for exactly this, for indexes.

create_all stays as the bootstrap for fresh and test databases; Alembic owns
changes to databases that already exist. Existing deployments adopt the
baseline with 'alembic stamp 0001'."
```

---

## Task 2: Add `revision` to the backend schema

**Files:**
- Modify: `backend/app/models/note.py`, `backend/app/models/folder.py`, `backend/app/models/artifact.py`
- Create: `backend/alembic/versions/0002_add_revision.py`

- [ ] **Step 1: Declare the column on the four models**

In each of `Note`, `Folder`, `Artifact` and `ArtifactComment`, add alongside the
other columns:

```python
    # Server-assigned optimistic-concurrency counter. Incremented on every
    # accepted write; clients send back the revision they based their edit on
    # so a conflict can be detected without trusting device clocks. Not read
    # by anything yet -- see the revisions plan.
    revision: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="1", default=1
    )
```

Add `Integer` to the `sqlalchemy` import at the top of each file if it is not
already imported.

`server_default` matters as much as `default`: it is what fills the column for
rows that already exist when the migration runs, and for any write that does
not go through the ORM.

- [ ] **Step 2: Generate the migration**

```bash
cd backend
createdb archset_baseline_tmp 2>/dev/null || true
export MIG_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/archset_baseline_tmp"
DATABASE_URL="$MIG_URL" alembic upgrade head          # scratch DB at baseline
DATABASE_URL="$MIG_URL" alembic revision --autogenerate -m "add revision" --rev-id 0002
```

- [ ] **Step 3: Read the generated migration**

It must contain exactly four `op.add_column` calls, one per table, each with
`nullable=False` and `server_default="1"`. No other changes. If autogenerate
emitted anything else, the baseline was wrong — stop and fix Task 1.

Rename to `backend/alembic/versions/0002_add_revision.py` if needed.

- [ ] **Step 4: Verify it applies and is reversible**

```bash
DATABASE_URL="$MIG_URL" alembic upgrade head
DATABASE_URL="$MIG_URL" alembic current      # expect: 0002 (head)
DATABASE_URL="$MIG_URL" alembic downgrade -1
DATABASE_URL="$MIG_URL" alembic current      # expect: 0001
DATABASE_URL="$MIG_URL" alembic upgrade head
```

Confirm the column exists and existing rows got the default:

```bash
psql "postgresql://postgres:postgres@localhost:5432/archset_baseline_tmp" \
  -c "insert into users (id, email, hashed_password, created_at) values ('u1','a@b.c','x', now()) on conflict do nothing;" \
  -c "insert into folders (id, user_id, name, created_at) values ('f1','u1','F', now());" \
  -c "select id, revision from folders;"
```
Expected: one row, `revision = 1`.

```bash
dropdb archset_baseline_tmp
```

- [ ] **Step 5: Run the backend tests**

```bash
cd backend && python -m pytest -q
```
Expected: no new failures. If pytest hangs with no output, Postgres is not
running — `docker compose up -d` first.

- [ ] **Step 6: Commit**

```bash
git add backend/app/models backend/alembic/versions
git commit -m "feat(backend): add server-assigned revision column to synced tables

Optimistic-concurrency counter for conflict detection. Nothing reads it yet;
this lands the schema so it can be applied and verified against production
before any behaviour depends on it.

server_default backfills rows that already exist."
```

---

## Task 3: Add `baseRevision` to the client schema

**Files:**
- Modify: `lib/data/database/app_database.dart`
- Test: `test/data/database/app_database_migration_test.dart`

`baseRevision` is the server revision a local edit was based on.

**Deviation from the spec, deliberate.** Spec section 1 lists `authorId`,
`isShared` and `ownerAuthorId` in the same v10 migration. All three exist only
to serve sharing, and nothing in this plan or the next one writes them — adding
them now would put columns in the schema that no code fills. They arrive with
sharing, in its own migration. Drift migrations are cheap; speculative columns
are not.

- [ ] **Step 1: Write the failing migration test**

Read `test/data/database/app_database_migration_test.dart` first to match its
existing style. Add:

```dart
  test('v9 -> v10 adds baseRevision without losing rows', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement('PRAGMA user_version = 9');
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n1',
            title: 'Раскоп 3',
            content: '',
            date: DateTime(2026, 8, 2),
            ownerKey: const Value('ivan'),
          ),
        );

    final rows = await db.select(db.notes).get();

    expect(rows, hasLength(1));
    expect(rows.single.baseRevision, isNull);
  });
```

- [ ] **Step 2: Run it and watch it fail**

```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
flutter test test/data/database/app_database_migration_test.dart --concurrency=1
```
Expected: FAIL — `baseRevision` is not defined on the generated row class.

- [ ] **Step 3: Declare the column**

In `lib/data/database/app_database.dart`, add to **each** of `Folders`, `Notes`,
`ImageMetadata` and `ArtifactComments`:

```dart
  /// The server revision this row's local state was based on. Null means the
  /// row has never been to the server. Written by the sync layer, not by the
  /// repository.
  IntColumn get baseRevision => integer().nullable()();
```

- [ ] **Step 4: Bump the schema version and add the migration**

Change `int get schemaVersion => 9;` to `=> 10;`.

At the end of the `onUpgrade` chain, after the existing `if (from < 9)` block.
Written out per table rather than looped: the four table classes have no shared
supertype exposing `baseRevision`, so a loop would not type-check.

```dart
      if (from < 10) {
        await m.addColumn(notes, notes.baseRevision);
        await m.addColumn(folders, folders.baseRevision);
        await m.addColumn(imageMetadata, imageMetadata.baseRevision);
        await m.addColumn(artifactComments, artifactComments.baseRevision);
      }
```

- [ ] **Step 5: Regenerate the drift code**

```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
```
Expected: `app_database.g.dart` regenerated with the eight new columns.

- [ ] **Step 6: Run the tests**

```bash
flutter test test/data/database/app_database_migration_test.dart --concurrency=1
flutter test --concurrency=1
```
Expected: the migration file passes; the full suite gains no new failures.

Two failures are **pre-existing** and not yours (both reproduce on a tree
without this change):
- `test/presentation/audio/bloc/audio_bloc_test.dart` → "segment management …" —
  timing flake, ~1 run in 3, fails even in isolation.
- `test/core/composition_root_test.dart` → `MissingPluginException` for the
  `record` plugin — fails deterministically.

Anything else is a regression.

- [ ] **Step 7: Commit**

```bash
git add lib/data/database/app_database.dart lib/data/database/app_database.g.dart test/data/database/app_database_migration_test.dart
git commit -m "feat(db): add baseRevision column (schema v10)

Records the server revision a local edit was based on, so conflict detection
can work off a server-assigned counter rather than device clocks -- two phones
offline in the field for a week drift apart, and comparing timestamps would
silently pick the wrong winner.

Nothing reads it yet."
```

---

## Deployment checkpoint

Do this **before** starting the conflict-detection plan. The whole point of
separating these is to prove the migration against the real database while
nothing depends on it.

- [ ] **1. Adopt the baseline on production (once)**

```bash
cd backend
DATABASE_URL="<railway postgres url>" alembic stamp 0001
```

- [ ] **2. Apply the revision migration**

```bash
DATABASE_URL="<railway postgres url>" alembic upgrade head
DATABASE_URL="<railway postgres url>" alembic current
```
Expected: `0002 (head)`.

- [ ] **3. Confirm the column landed on real data**

```bash
psql "<railway postgres url>" -c "select id, revision from notes limit 5;"
```
Expected: existing notes, all with `revision = 1`.

- [ ] **4. Deploy the backend and smoke-test**

Existing clients know nothing about `revision`, and nothing on the server reads
it, so sync must behave exactly as before. Verify by syncing from the phone and
confirming notes still round-trip.

---

## What this plan deliberately does not do

No conflict detection, no `409`, no forking, no client change to what is sent or
stored. Those are the next plan, and they are only safe once the checkpoint
above has passed.
