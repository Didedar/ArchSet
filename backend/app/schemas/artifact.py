"""
Artifact schemas for request/response validation.
"""

from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class ArtifactBase(BaseModel):
    """Base artifact fields."""
    note_id: Optional[str] = None
    image_path: str = ""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    analysis_result: Optional[str] = None


class ArtifactResponse(ArtifactBase):
    """Artifact response with all fields."""
    id: str
    user_id: str
    captured_at: datetime
    created_at: datetime
    updated_at: datetime
    synced_at: Optional[datetime] = None
    is_deleted: bool = False

    revision: int = 1

    class Config:
        from_attributes = True


class ArtifactSyncItem(BaseModel):
    """Artifact data for sync operations."""
    id: str
    note_id: Optional[str] = None
    image_path: str = ""
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    analysis_result: Optional[str] = None
    captured_at: datetime
    updated_at: datetime
    is_deleted: bool = False
    # The revision the client based this edit on. None means "I have never
    # synced this row" or "I am an old client that predates revisions" --
    # both fall through to the previous last-write-wins behaviour.
    base_revision: Optional[int] = None


class ArtifactCommentBase(BaseModel):
    """Base artifact comment fields."""
    artifact_id: str
    body: str = ""


class ArtifactCommentResponse(ArtifactCommentBase):
    """Artifact comment response with all fields."""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    synced_at: Optional[datetime] = None
    is_deleted: bool = False

    revision: int = 1

    class Config:
        from_attributes = True


class ArtifactCommentSyncItem(BaseModel):
    """Artifact comment data for sync operations."""
    id: str
    artifact_id: str
    body: str = ""
    created_at: datetime
    updated_at: datetime
    is_deleted: bool = False
    # The revision the client based this edit on. None means "I have never
    # synced this row" or "I am an old client that predates revisions" --
    # both fall through to the previous last-write-wins behaviour.
    base_revision: Optional[int] = None
