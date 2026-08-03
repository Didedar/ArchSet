"""
Sync API endpoint for offline-first synchronization.
"""

from datetime import datetime
from fastapi import APIRouter, Depends, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.user import User
from ..schemas.note import SyncRequest, SyncResponse
from ..services.sync_service import SyncService
from ..utils.access import accessible_folder_ids
from ..utils.security import get_current_user

router = APIRouter(prefix="/sync", tags=["Synchronization"])


@router.post("", response_model=SyncResponse)
async def sync_data(
    sync_request: SyncRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Synchronize local data with server.
    
    This endpoint handles bidirectional sync:
    1. Client sends local changes (notes, folders, artifacts and comments)
    2. Server applies changes using "last write wins"
    3. Server returns all changes since client's last sync

    **Conflict Resolution**: A client that sends `base_revision` only wins if
    that is still the row's current `revision` on the server. A mismatch means
    someone else wrote first: the server keeps its version and, for notes,
    names the id in `conflicted_note_ids` so the client can fork its own copy
    instead of losing it. Folders and artifacts drop the stale write silently.

    Reported per item inside a 200 rather than as an HTTP 409 because this
    endpoint is a batch -- one lost race must not reject every other row.

    Clients that send no `base_revision` fall back to the previous
    last-write-wins behaviour, so installs that predate revisions keep
    working.

    **Deleted Items**: Items with `is_deleted: true` will be soft-deleted
    on the server. Clients should hide these but keep them for sync.

    **Ordering**: Collections are synced parents-first (folders -> notes ->
    artifacts -> artifact comments) so that references between them resolve
    within a single request. Every collection is optional, so clients that
    don't send artifacts behave exactly as before.
    """
    service = SyncService(db)
    accessible = await accessible_folder_ids(db, current_user)

    # Sync folders -- before notes, so note.folder_id can resolve (a note's
    # folder_id FK must reference a folder row that already exists).
    synced_folders = await service.sync_folders(
        user=current_user,
        client_folders=sync_request.folders,
        last_sync_at=sync_request.last_sync_at
    )

    # Sync notes
    synced_notes, conflicted_note_ids = await service.sync_notes(
        user=current_user,
        client_notes=sync_request.notes,
        last_sync_at=sync_request.last_sync_at,
        background_tasks=background_tasks
    )

    # Sync artifacts -- after notes, so artifact.note_id can resolve
    synced_artifacts = await service.sync_artifacts(
        user=current_user,
        client_artifacts=sync_request.artifacts,
        last_sync_at=sync_request.last_sync_at
    )

    # Sync artifact comments -- after artifacts, so comment.artifact_id can resolve
    synced_artifact_comments = await service.sync_artifact_comments(
        user=current_user,
        client_comments=sync_request.artifact_comments,
        last_sync_at=sync_request.last_sync_at
    )

    return SyncResponse(
        notes=synced_notes,
        folders=synced_folders,
        artifacts=synced_artifacts,
        artifact_comments=synced_artifact_comments,
        sync_timestamp=datetime.utcnow(),
        conflicted_note_ids=conflicted_note_ids,
        accessible_folder_ids=sorted(accessible),
    )
