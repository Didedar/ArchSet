-- Run with: psql "$DATABASE_URL" -f backend/scripts/add_indexes.sql
--
-- Why this file exists: the app creates its schema with Base.metadata.create_all(),
-- which only creates indexes alongside a table it is creating for the first time.
-- On a database whose "notes"/"folders" tables already exist, the Index() entries
-- declared in app/models/note.py and app/models/folder.py are silently ignored, so
-- they have to be applied by hand once. A fresh database gets them automatically
-- and every statement below is a no-op thanks to IF NOT EXISTS.
--
-- CONCURRENTLY avoids taking a write lock on the table, so this is safe to run
-- against a live database. It cannot run inside a transaction block: execute this
-- file with psql (which autocommits each statement), not from within BEGIN/COMMIT.
-- Note that a CONCURRENTLY build can fail and leave an INVALID index behind; if
-- that happens, DROP INDEX the invalid one and re-run.

-- notes: list/filter a user's entries by date (routers/notes.py list_notes)
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_notes_user_id_date
    ON notes (user_id, date);

-- notes: the same listing with the default is_deleted = false filter applied
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_notes_user_id_is_deleted_date
    ON notes (user_id, is_deleted, date);

-- notes: incremental sync pulls rows changed since the client's last sync
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_notes_user_id_updated_at
    ON notes (user_id, updated_at);

-- folders: incremental sync pulls folders changed since the client's last sync
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_folders_user_id_updated_at
    ON folders (user_id, updated_at);

-- folders: folder listing is ordered by created_at (routers/folders.py list_folders)
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_folders_user_id_created_at
    ON folders (user_id, created_at);
