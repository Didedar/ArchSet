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

from app.models.artifact import Artifact, ArtifactComment
from app.models.folder import Folder
from app.models.note import Note
from app.models.user import User
from app.schemas.artifact import ArtifactCommentSyncItem, ArtifactSyncItem
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


def _artifact_sync_item(**overrides) -> ArtifactSyncItem:
    defaults = dict(
        id="artifact-1",
        note_id=None,
        image_path="/local/photos/sherd.jpg",
        latitude=41.3111,
        longitude=69.2797,
        analysis_result=None,
        captured_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        is_deleted=False,
    )
    defaults.update(overrides)
    return ArtifactSyncItem(**defaults)


def _artifact_comment_sync_item(**overrides) -> ArtifactCommentSyncItem:
    defaults = dict(
        id="comment-1",
        artifact_id="artifact-1",
        body="Wheel-thrown, likely 11th century.",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        is_deleted=False,
    )
    defaults.update(overrides)
    return ArtifactCommentSyncItem(**defaults)


@pytest.mark.asyncio
async def test_sync_notes_works_without_background_tasks(
    db_session: AsyncSession, test_user: User
):
    """background_tasks is an Optional[BackgroundTasks] param -- calling the
    service directly (as opposed to through the router, which always
    supplies one) must not require it.
    """
    service = SyncService(db_session)

    result, _ = await service.sync_notes(
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

    result, _ = await service.sync_notes(
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


@pytest.mark.asyncio
async def test_sync_artifacts_processes_multiple_items_in_one_call(
    db_session: AsyncSession, test_user: User
):
    service = SyncService(db_session)

    result = await service.sync_artifacts(
        user=test_user,
        client_artifacts=[
            _artifact_sync_item(id="a"),
            _artifact_sync_item(id="b"),
            _artifact_sync_item(id="c"),
        ],
        last_sync_at=None,
    )

    assert {a.id for a in result} == {"a", "b", "c"}


@pytest.mark.asyncio
async def test_sync_artifacts_stamps_synced_at_on_new_rows(
    db_session: AsyncSession, test_user: User
):
    """synced_at is what lets a later incremental pull notice server-side
    writes whose updated_at is older than the client's last_sync_at.
    """
    service = SyncService(db_session)

    result = await service.sync_artifacts(
        user=test_user,
        client_artifacts=[_artifact_sync_item(id="stamped")],
        last_sync_at=None,
    )

    assert result[0].synced_at is not None


@pytest.mark.asyncio
async def test_sync_artifacts_does_not_index_anything_in_the_vector_db(
    db_session: AsyncSession, test_user: User
):
    """Artifacts are photo metadata, not diary prose -- unlike sync_notes,
    sync_artifacts takes no background_tasks and must schedule no RAG work.
    """
    service = SyncService(db_session)
    background_tasks = MagicMock()

    await service.sync_artifacts(
        user=test_user,
        client_artifacts=[_artifact_sync_item(id="a")],
        last_sync_at=None,
    )

    background_tasks.add_task.assert_not_called()


@pytest.mark.asyncio
async def test_sync_artifact_comments_processes_multiple_items_in_one_call(
    db_session: AsyncSession, test_user: User
):
    now = datetime.utcnow()
    db_session.add(
        Artifact(
            id="artifact-1",
            user_id=test_user.id,
            image_path="/server/photo.jpg",
            captured_at=now,
            updated_at=now,
        )
    )
    await db_session.commit()

    service = SyncService(db_session)
    result = await service.sync_artifact_comments(
        user=test_user,
        client_comments=[
            _artifact_comment_sync_item(id="c1"),
            _artifact_comment_sync_item(id="c2"),
        ],
        last_sync_at=None,
    )

    assert {c.id for c in result} == {"c1", "c2"}


@pytest.mark.asyncio
async def test_sync_artifact_comments_keeps_an_existing_comments_artifact_id(
    db_session: AsyncSession, test_user: User
):
    """Deliberate: updates touch body/is_deleted only.

    Re-parenting a comment isn't a real client operation, and honouring an
    incoming artifact_id would mean re-validating the foreign key on every
    update. The comment stays where it was created.
    """
    now = datetime.utcnow()
    db_session.add_all(
        [
            Artifact(
                id="artifact-1",
                user_id=test_user.id,
                image_path="/a.jpg",
                captured_at=now,
                updated_at=now,
            ),
            Artifact(
                id="artifact-2",
                user_id=test_user.id,
                image_path="/b.jpg",
                captured_at=now,
                updated_at=now,
            ),
            ArtifactComment(
                id="comment-1",
                artifact_id="artifact-1",
                user_id=test_user.id,
                body="Original",
                created_at=now,
                updated_at=now,
            ),
        ]
    )
    await db_session.commit()

    service = SyncService(db_session)
    await service.sync_artifact_comments(
        user=test_user,
        client_comments=[
            _artifact_comment_sync_item(
                id="comment-1",
                artifact_id="artifact-2",
                body="Moved?",
                updated_at=now + timedelta(hours=1),
            )
        ],
        last_sync_at=None,
    )

    comment = await db_session.get(ArtifactComment, "comment-1")
    await db_session.refresh(comment)
    assert comment.body == "Moved?"
    assert comment.artifact_id == "artifact-1"


@pytest.mark.asyncio
async def test_sync_artifact_comments_skips_orphans_without_raising(
    db_session: AsyncSession, test_user: User
):
    service = SyncService(db_session)

    result = await service.sync_artifact_comments(
        user=test_user,
        client_comments=[_artifact_comment_sync_item(id="orphan", artifact_id="missing")],
        last_sync_at=None,
    )

    assert result == []


class TestRevisionGuard:
    """Optimistic concurrency: a write is accepted only if the client edited
    from the revision the server currently holds.

    The point is to stop a device with a fast clock -- or one that has been
    offline for a week -- from silently overwriting an edit it never saw.
    Timestamps cannot express that; a server-assigned counter can.
    """

    @pytest.mark.asyncio
    async def test_a_first_write_stamps_revision_1(
        self, db_session: AsyncSession, test_user: User
    ):
        service = SyncService(db_session)
        await service.sync_notes(
            user=test_user,
            client_notes=[_note_sync_item(id="n1")],
            last_sync_at=None,
        )
        await db_session.flush()

        note = await db_session.get(Note, "n1")
        assert note.revision == 1

    @pytest.mark.asyncio
    async def test_a_write_from_the_current_revision_is_accepted_and_bumps_it(
        self, db_session: AsyncSession, test_user: User
    ):
        service = SyncService(db_session)
        await service.sync_notes(
            user=test_user,
            client_notes=[_note_sync_item(id="n1", title="Layer 2")],
            last_sync_at=None,
        )
        await db_session.flush()

        await service.sync_notes(
            user=test_user,
            client_notes=[
                _note_sync_item(
                    id="n1",
                    title="Layer 2 revised",
                    updated_at=datetime.utcnow() + timedelta(hours=1),
                    base_revision=1,
                )
            ],
            last_sync_at=None,
        )
        await db_session.flush()

        note = await db_session.get(Note, "n1")
        assert note.title == "Layer 2 revised"
        assert note.revision == 2

    @pytest.mark.asyncio
    async def test_a_stale_base_revision_is_rejected_even_with_a_newer_clock(
        self, db_session: AsyncSession, test_user: User
    ):
        """The case the whole feature exists for.

        Device B has been in the field, edited from revision 1, and has a
        later wall clock than device A's accepted edit. Last-write-wins would
        hand it the win; the revision guard must not.
        """
        service = SyncService(db_session)
        await service.sync_notes(
            user=test_user,
            client_notes=[_note_sync_item(id="n1", title="Layer 2")],
            last_sync_at=None,
        )
        await db_session.flush()

        # Device A: accepted, revision -> 2.
        await service.sync_notes(
            user=test_user,
            client_notes=[
                _note_sync_item(
                    id="n1",
                    title="From device A",
                    updated_at=datetime.utcnow() + timedelta(hours=1),
                    base_revision=1,
                )
            ],
            last_sync_at=None,
        )
        await db_session.flush()

        # Device B: still thinks the note is at revision 1, and its clock is
        # even further ahead.
        _, conflicted = await service.sync_notes(
            user=test_user,
            client_notes=[
                _note_sync_item(
                    id="n1",
                    title="From device B",
                    updated_at=datetime.utcnow() + timedelta(hours=2),
                    base_revision=1,
                )
            ],
            last_sync_at=None,
        )
        await db_session.flush()

        note = await db_session.get(Note, "n1")
        assert note.title == "From device A", "the stale write must not land"
        assert note.revision == 2, "a rejected write must not bump the revision"
        assert conflicted == ["n1"]

    @pytest.mark.asyncio
    async def test_a_client_that_sends_no_base_revision_keeps_the_old_behaviour(
        self, db_session: AsyncSession, test_user: User
    ):
        """Backward compatibility: installs that predate revisions must keep
        working, on plain last-write-wins."""
        service = SyncService(db_session)
        await service.sync_notes(
            user=test_user,
            client_notes=[_note_sync_item(id="n1", title="Original")],
            last_sync_at=None,
        )
        await db_session.flush()

        _, conflicted = await service.sync_notes(
            user=test_user,
            client_notes=[
                _note_sync_item(
                    id="n1",
                    title="Newer, no base_revision",
                    updated_at=datetime.utcnow() + timedelta(hours=1),
                )
            ],
            last_sync_at=None,
        )
        await db_session.flush()

        note = await db_session.get(Note, "n1")
        assert note.title == "Newer, no base_revision"
        assert conflicted == []

    @pytest.mark.asyncio
    async def test_a_stale_folder_write_is_dropped_without_being_reported(
        self, db_session: AsyncSession, test_user: User
    ):
        """Folders resolve last-write-wins rather than forking: two dig sites
        where there was one would be worse than a lost rename."""
        service = SyncService(db_session)
        await service.sync_folders(
            user=test_user,
            client_folders=[_folder_sync_item(id="f1", name="Trench 3")],
            last_sync_at=None,
        )
        await db_session.flush()

        await service.sync_folders(
            user=test_user,
            client_folders=[
                _folder_sync_item(
                    id="f1",
                    name="Stale rename",
                    updated_at=datetime.utcnow() + timedelta(hours=2),
                    base_revision=99,
                )
            ],
            last_sync_at=None,
        )
        await db_session.flush()

        folder = await db_session.get(Folder, "f1")
        assert folder.name == "Trench 3"
