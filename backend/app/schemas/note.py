"""
Note schemas for request/response validation.
"""

from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List


class NoteBase(BaseModel):
    """Base note fields."""
    title: str = ""
    content: str = ""
    folder_id: Optional[str] = None
    audio_path: Optional[str] = None
    date: Optional[datetime] = None


class NoteCreate(NoteBase):
    """Schema for creating a note."""
    id: Optional[str] = None  # Allow client to specify ID for sync


class NoteUpdate(BaseModel):
    """Schema for updating a note."""
    title: Optional[str] = None
    content: Optional[str] = None
    folder_id: Optional[str] = None
    audio_path: Optional[str] = None
    date: Optional[datetime] = None


class NoteResponse(NoteBase):
    """Note response with all fields."""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    synced_at: Optional[datetime] = None
    is_deleted: bool = False
    
    class Config:
        from_attributes = True


class NoteSyncItem(BaseModel):
    """Note data for sync operations."""
    id: str
    title: str = ""
    content: str = ""
    folder_id: Optional[str] = None
    audio_path: Optional[str] = None
    date: datetime
    updated_at: datetime
    is_deleted: bool = False


class SyncRequest(BaseModel):
    """Sync request with local changes."""
    notes: List[NoteSyncItem] = []
    folders: List["FolderSyncItem"] = []
    last_sync_at: Optional[datetime] = None


class SyncResponse(BaseModel):
    """Sync response with server changes."""
    notes: List[NoteResponse] = []
    folders: List["FolderResponse"] = []
    sync_timestamp: datetime


# Avoid circular import
from .folder import FolderSyncItem, FolderResponse
SyncRequest.model_rebuild()
SyncResponse.model_rebuild()
