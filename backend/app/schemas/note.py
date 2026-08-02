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
    revision: int = 1

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
    # The revision the client based this edit on. None means "I have never
    # synced this row" (a new item) or "I am an old client that predates
    # revisions" -- both fall through to the previous last-write-wins
    # behaviour so existing installs keep working.
    base_revision: Optional[int] = None


class SyncRequest(BaseModel):
    """Sync request with local changes.

    Every collection defaults to an empty list so older clients that only
    know about `notes`/`folders` keep working unchanged.
    """
    notes: List[NoteSyncItem] = []
    folders: List["FolderSyncItem"] = []
    artifacts: List["ArtifactSyncItem"] = []
    artifact_comments: List["ArtifactCommentSyncItem"] = []
    last_sync_at: Optional[datetime] = None


class SyncResponse(BaseModel):
    """Sync response with server changes."""
    notes: List[NoteResponse] = []
    folders: List["FolderResponse"] = []
    artifacts: List["ArtifactResponse"] = []
    artifact_comments: List["ArtifactCommentResponse"] = []
    sync_timestamp: datetime

    # Notes whose base_revision did not match the server's current revision.
    # Their server-side version is included in `notes` above; the client keeps
    # that under the original id and forks its own copy. Per-item rather than
    # an HTTP 409 because this endpoint is a batch -- one lost race must not
    # reject every other row in the request.
    conflicted_note_ids: List[str] = []


# Avoid circular import
from .folder import FolderSyncItem, FolderResponse
from .artifact import (
    ArtifactSyncItem,
    ArtifactResponse,
    ArtifactCommentSyncItem,
    ArtifactCommentResponse,
)
SyncRequest.model_rebuild()
SyncResponse.model_rebuild()
