"""
Folder schemas for request/response validation.
"""

from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class FolderBase(BaseModel):
    """Base folder fields."""
    name: str
    color: str = "#E8B731"


class FolderCreate(FolderBase):
    """Schema for creating a folder."""
    id: Optional[str] = None  # Allow client to specify ID for sync


class FolderUpdate(BaseModel):
    """Schema for updating a folder."""
    name: Optional[str] = None
    color: Optional[str] = None


class FolderResponse(FolderBase):
    """Folder response with all fields."""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    is_deleted: bool = False
    
    revision: int = 1

    class Config:
        from_attributes = True


class FolderSyncItem(BaseModel):
    """Folder data for sync operations."""
    id: str
    name: str
    color: str = "#E8B731"
    updated_at: datetime
    is_deleted: bool = False
    # The revision the client based this edit on. None means "I have never
    # synced this row" or "I am an old client that predates revisions" --
    # both fall through to the previous last-write-wins behaviour.
    base_revision: Optional[int] = None
