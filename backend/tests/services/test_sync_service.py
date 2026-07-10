"""Direct unit tests for SyncService's conflict-resolution logic.

tests/routers/test_sync.py already covers the HTTP-level contract (auth,
status codes, single-item scenarios). These tests exercise SyncService
directly to cover things that are awkward to assert through the HTTP layer:
background_tasks being optional, multiple items in one call, and exactly
which writes trigger a vector-DB indexing background task.
"""

from datetime import datetime, timedelta
from unittest.mock import MagicMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.folder import Folder
from app.models.note import Note
from app.models.user import User
from app.schemas.folder import FolderSyncItem
from app.schemas.note import NoteSyncItem
from app.services.rag_service import rag_service
from app.services.sync_service import SyncService


def _note_sync_item(**overrides) -> NoteSyncItem:
    defaults = dict(
        id="note-1",
        title="Title",
        content="Content",
        date=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        is_deleted=False,
    )
    defaults.update(overrides)
    return NoteSyncItem(**defaults)


def _folder_sync_item(**overrides) -> FolderSyncItem:
    defaults = dict(
        id="folder-1",
        name="Folder",
        updated_at=datetime.utcnow(),
        is_deleted=False,
    )
    defaults.update(overrides)
    return FolderSyncItem(**defaults)


@pytest.mark.asyncio
async def test_sync_notes_works_without_background_tasks(
    db_session: AsyncSession, test_user: User
):
    """background_tasks is an Optional[BackgroundTasks] param -- calling the
    service directly (as opposed to through the router, which always
    supplies one) must not require it.
    """
    service = SyncService(db_session)

    result = await service.sync_notes(
        user=test_user,
        client_notes=[_note_sync_item(id="no-bg-tasks")],
        last_sync_at=None,
        background_tasks=None,
    )

    assert [n.id for n in result] == ["no-bg-tasks"]


@pytest.mark.asyncio
async def test_sync_notes_processes_multiple_items_in_one_call(
    db_session: AsyncSession, test_user: User
):
    service = SyncService(db_session)

    result = await service.sync_notes(
        user=test_user,
        client_notes=[_note_sync_item(id="a"), _note_sync_item(id="b"), _note_sync_item(id="c")],
        last_sync_at=None,
    )

    assert {n.id for n in result} == {"a", "b", "c"}


@pytest.mark.asyncio
async def test_sync_notes_only_indexes_notes_with_content_or_title(
    db_session: AsyncSession, test_user: User
):
    background_tasks = MagicMock()
    service = SyncService(db_session)

    await service.sync_notes(
        user=test_user,
        client_notes=[
            _note_sync_item(id="has-content", title="", content="real content"),
            _note_sync_item(id="blank", title="", content=""),
        ],
        last_sync_at=None,
        background_tasks=background_tasks,
    )

    indexed_note_ids = {
        call.kwargs["note_id"] for call in background_tasks.add_task.call_args_list
    }
    assert indexed_note_ids == {"has-content"}


@pytest.mark.asyncio
async def test_sync_notes_deleting_an_existing_note_triggers_index_removal_not_reindex(
    db_session: AsyncSession, test_user: User
):
    existing = Note(id="to-delete", user_id=test_user.id, title="T", content="C")
    db_session.add(existing)
    await db_session.commit()

    background_tasks = MagicMock()
    service = SyncService(db_session)

    await service.sync_notes(
        user=test_user,
        client_notes=[
            _note_sync_item(
                id="to-delete",
                updated_at=datetime.utcnow() + timedelta(hours=1),
                is_deleted=True,
            )
        ],
        last_sync_at=None,
        background_tasks=background_tasks,
    )

    # rag_service's methods are patched to AsyncMocks by the autouse
    # _stub_rag_background_tasks conftest fixture (a real singleton, shared
    # by every module that imports it) -- so identity, not __name__,
    # distinguishes which method got scheduled here.
    called_fns = {call.args[0] for call in background_tasks.add_task.call_args_list}
    assert called_fns == {rag_service.delete_note_from_index}


@pytest.mark.asyncio
async def test_sync_folders_works_without_last_sync_at(
    db_session: AsyncSession, test_user: User
):
    service = SyncService(db_session)

    result = await service.sync_folders(
        user=test_user,
        client_folders=[_folder_sync_item(id="new-folder")],
        last_sync_at=None,
    )

    assert [f.id for f in result] == ["new-folder"]


@pytest.mark.asyncio
async def test_sync_folders_updates_only_when_client_is_newer(
    db_session: AsyncSession, test_user: User
):
    existing = Folder(id="folder-1", user_id=test_user.id, name="Old name")
    db_session.add(existing)
    await db_session.commit()
    await db_session.refresh(existing)

    service = SyncService(db_session)
    await service.sync_folders(
        user=test_user,
        client_folders=[
            _folder_sync_item(
                id="folder-1",
                name="Stale name",
                updated_at=existing.updated_at - timedelta(hours=1),
            )
        ],
        last_sync_at=None,
    )

    await db_session.refresh(existing)
    assert existing.name == "Old name"
