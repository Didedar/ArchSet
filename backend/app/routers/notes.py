"""
Notes API endpoints.
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from ..database import get_db
import os
from ..models.note import Note
from ..models.user import User
from ..models.folder import Folder
from ..schemas.note import NoteCreate, NoteUpdate, NoteResponse
from ..utils.security import get_current_user
from ..services.rag_service import rag_service

router = APIRouter(prefix="/notes", tags=["Notes"])


@router.get("", response_model=List[NoteResponse])
async def list_notes(
    include_deleted: bool = False,
    folder_id: str = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all notes for the current user.
    
    - **include_deleted**: Include soft-deleted notes (for sync)
    - **folder_id**: Filter by folder (null for uncategorized)
    """
    query = select(Note).where(Note.user_id == current_user.id)
    
    if not include_deleted:
        query = query.where(Note.is_deleted == False)
    
    if folder_id is not None:
        query = query.where(Note.folder_id == folder_id)
    
    query = query.order_by(Note.date.desc())
    
    result = await db.execute(query)
    notes = result.scalars().all()
    
    return [NoteResponse.model_validate(note) for note in notes]


@router.post("", response_model=NoteResponse, status_code=201)
async def create_note(
    note_data: NoteCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new note.
    
    The note ID can be specified by the client for sync purposes.
    """
    note = Note(
        id=note_data.id if note_data.id else None,
        user_id=current_user.id,
        title=note_data.title,
        content=note_data.content,
        folder_id=note_data.folder_id,
        audio_path=note_data.audio_path,
        date=note_data.date or datetime.utcnow(),
        synced_at=datetime.utcnow()
    )
    
    db.add(note)
    await db.commit()
    await db.refresh(note)
    
    # Sync to vector DB
    if note.content:
        background_tasks.add_task(
            rag_service.sync_diary_to_vector_db,
            note_id=note.id,
            text=note.content,
            user_id=current_user.id,
            title=note.title
        )
    
    return NoteResponse.model_validate(note)


@router.get("/{note_id}", response_model=NoteResponse)
async def get_note(
    note_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific note by ID."""
    result = await db.execute(
        select(Note).where(
            Note.id == note_id,
            Note.user_id == current_user.id
        )
    )
    note = result.scalar_one_or_none()
    
    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    
    return NoteResponse.model_validate(note)


@router.put("/{note_id}", response_model=NoteResponse)
async def update_note(
    note_id: str,
    note_data: NoteUpdate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update an existing note."""
    result = await db.execute(
        select(Note).where(
            Note.id == note_id,
            Note.user_id == current_user.id
        )
    )
    note = result.scalar_one_or_none()
    
    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    
    # Update fields if provided
    if note_data.title is not None:
        note.title = note_data.title
    if note_data.content is not None:
        note.content = note_data.content
    if note_data.folder_id is not None:
        note.folder_id = note_data.folder_id
    if note_data.audio_path is not None:
        note.audio_path = note_data.audio_path
    if note_data.date is not None:
        note.date = note_data.date
    
    note.synced_at = datetime.utcnow()
    
    await db.commit()
    await db.refresh(note)
    
    # Sync to vector DB if content or title changed
    if (note_data.content is not None) or (note_data.title is not None):
        background_tasks.add_task(
            rag_service.sync_diary_to_vector_db,
            note_id=note.id,
            text=note.content if note_data.content is not None else note.content,
            user_id=current_user.id,
            title=note.title
        )
    
    return NoteResponse.model_validate(note)


@router.delete("/{note_id}", status_code=204)
async def delete_note(
    note_id: str,
    hard_delete: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete a note.
    
    - **hard_delete**: If true, permanently delete. Otherwise soft delete.
    """
    result = await db.execute(
        select(Note).where(
            Note.id == note_id,
            Note.user_id == current_user.id
        )
    )
    note = result.scalar_one_or_none()
    
    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    
    if hard_delete:
        # Delete associated media files
        if note.audio_path and os.path.exists(note.audio_path):
            try:
                os.remove(note.audio_path)
            except OSError:
                pass  # Ignore if file not found or other error

        # TODO: Parse note.content (JSON/Delta) to find and delete images
        # For now, we only handle audio as it's the primary external file

        await db.delete(note)
    else:
        note.is_deleted = True
        note.updated_at = datetime.utcnow()
    
    await db.commit()
