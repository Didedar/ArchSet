"""
Folders API endpoints.
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from ..database import get_db
from ..models.folder import Folder
from ..models.note import Note
from ..models.user import User
from ..schemas.folder import FolderCreate, FolderUpdate, FolderResponse
from ..utils.security import get_current_user

router = APIRouter(prefix="/folders", tags=["Folders"])


@router.get("", response_model=List[FolderResponse])
async def list_folders(
    include_deleted: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all folders for the current user.
    
    - **include_deleted**: Include soft-deleted folders (for sync)
    """
    query = select(Folder).where(Folder.user_id == current_user.id)
    
    if not include_deleted:
        query = query.where(Folder.is_deleted == False)
    
    query = query.order_by(Folder.created_at.asc())
    
    result = await db.execute(query)
    folders = result.scalars().all()
    
    return [FolderResponse.model_validate(folder) for folder in folders]


@router.post("", response_model=FolderResponse, status_code=201)
async def create_folder(
    folder_data: FolderCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new folder.
    
    The folder ID can be specified by the client for sync purposes.
    """
    folder = Folder(
        id=folder_data.id if folder_data.id else None,
        user_id=current_user.id,
        name=folder_data.name,
        color=folder_data.color
    )
    
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    
    return FolderResponse.model_validate(folder)


@router.get("/{folder_id}", response_model=FolderResponse)
async def get_folder(
    folder_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific folder by ID."""
    result = await db.execute(
        select(Folder).where(
            Folder.id == folder_id,
            Folder.user_id == current_user.id
        )
    )
    folder = result.scalar_one_or_none()
    
    if not folder:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Folder not found"
        )
    
    return FolderResponse.model_validate(folder)


@router.put("/{folder_id}", response_model=FolderResponse)
async def update_folder(
    folder_id: str,
    folder_data: FolderUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update an existing folder."""
    result = await db.execute(
        select(Folder).where(
            Folder.id == folder_id,
            Folder.user_id == current_user.id
        )
    )
    folder = result.scalar_one_or_none()
    
    if not folder:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Folder not found"
        )
    
    if folder_data.name is not None:
        folder.name = folder_data.name
    if folder_data.color is not None:
        folder.color = folder_data.color
    
    await db.commit()
    await db.refresh(folder)
    
    return FolderResponse.model_validate(folder)


@router.delete("/{folder_id}", status_code=204)
async def delete_folder(
    folder_id: str,
    hard_delete: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete a folder.
    
    Notes in the folder will be moved to "All Notes" (folder_id = null).
    
    - **hard_delete**: If true, permanently delete. Otherwise soft delete.
    """
    result = await db.execute(
        select(Folder).where(
            Folder.id == folder_id,
            Folder.user_id == current_user.id
        )
    )
    folder = result.scalar_one_or_none()
    
    if not folder:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Folder not found"
        )
    
    # Move notes to "All Notes" (uncategorized)
    notes_result = await db.execute(
        select(Note).where(
            Note.folder_id == folder_id,
            Note.user_id == current_user.id
        )
    )
    notes = notes_result.scalars().all()
    for note in notes:
        note.folder_id = None
    
    if hard_delete:
        await db.delete(folder)
    else:
        folder.is_deleted = True
        folder.updated_at = datetime.utcnow()
    
    await db.commit()
