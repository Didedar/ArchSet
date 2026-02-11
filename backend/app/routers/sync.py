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
    1. Client sends local changes (notes and folders)
    2. Server applies changes using "last write wins"
    3. Server returns all changes since client's last sync
    
    **Conflict Resolution**: If the same item was modified on both
    client and server, the version with the later `updated_at`
    timestamp wins.
    
    **Deleted Items**: Items with `is_deleted: true` will be soft-deleted
    on the server. Clients should hide these but keep them for sync.
    """
    service = SyncService(db)
    
    # Sync notes
    synced_notes = await service.sync_notes(
        user=current_user,
        client_notes=sync_request.notes,
        last_sync_at=sync_request.last_sync_at,
        background_tasks=background_tasks
    )
    
    # Sync folders
    synced_folders = await service.sync_folders(
        user=current_user,
        client_folders=sync_request.folders,
        last_sync_at=sync_request.last_sync_at
    )
    
    return SyncResponse(
        notes=synced_notes,
        folders=synced_folders,
        sync_timestamp=datetime.utcnow()
    )
