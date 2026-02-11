"""
Sync service for handling offline-first synchronization.
"""

from datetime import datetime
from typing import List, Optional
import os 
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_

from ..models.note import Note
from ..models.folder import Folder
from ..models.user import User
from ..schemas.note import NoteSyncItem, NoteResponse
from ..schemas.folder import FolderSyncItem, FolderResponse


from fastapi import BackgroundTasks
from ..services.rag_service import rag_service

class SyncService:
    """Service for handling data synchronization."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def sync_notes(
        self,
        user: User,
        client_notes: List[NoteSyncItem],
        last_sync_at: Optional[datetime],
        background_tasks: Optional[BackgroundTasks] = None
    ) -> List[NoteResponse]:
        """
        Synchronize notes between client and server.
        
        Uses "last write wins" conflict resolution.
        
        Args:
            user: Current user
            client_notes: Notes from the client
            last_sync_at: Last sync timestamp from client
            background_tasks: Background tasks for indexing
            
        Returns:
            List of notes that changed on server since last sync
        """
        sync_time = datetime.utcnow()
        notes_to_index = []
        
        # Process client notes
        for client_note in client_notes:
            # Check if note exists
            result = await self.db.execute(
                select(Note).where(
                    Note.id == client_note.id,
                    Note.user_id == user.id
                )
            )
            existing_note = result.scalar_one_or_none()
            
            if existing_note:
                # Update if client version is newer
                if client_note.updated_at > existing_note.updated_at:
                    existing_note.title = client_note.title
                    existing_note.content = client_note.content
                    existing_note.folder_id = client_note.folder_id
                    existing_note.audio_path = client_note.audio_path
                    existing_note.date = client_note.date
                    existing_note.is_deleted = client_note.is_deleted
                    existing_note.updated_at = client_note.updated_at
                    existing_note.synced_at = sync_time

                    # If sync marks as deleted, remove media file
                    if client_note.is_deleted:
                        if existing_note.audio_path and os.path.exists(existing_note.audio_path):
                            try:
                                os.remove(existing_note.audio_path)
                                existing_note.audio_path = None # Clear path after delete
                            except OSError:
                                pass
                    else:
                        # If updated and not deleted, check if content changed/exists for indexing
                        if client_note.content or client_note.title:
                            notes_to_index.append(existing_note)
            else:
                # Create new note
                if not client_note.is_deleted:
                    new_note = Note(
                        id=client_note.id,
                        user_id=user.id,
                        title=client_note.title,
                        content=client_note.content,
                        folder_id=client_note.folder_id,
                        audio_path=client_note.audio_path,
                        date=client_note.date,
                        is_deleted=client_note.is_deleted,
                        updated_at=client_note.updated_at,
                        synced_at=sync_time
                    )
                    self.db.add(new_note)
                    if new_note.content or new_note.title:
                        notes_to_index.append(new_note)
        
        await self.db.flush()
        
        # Trigger background indexing
        if background_tasks and notes_to_index:
            for note in notes_to_index:
                if note.content: # double check content exists
                    background_tasks.add_task(
                        rag_service.sync_diary_to_vector_db,
                        note_id=note.id,
                        text=note.content,
                        user_id=user.id,
                        title=note.title or "Untitled"
                    )
        
        # Get server notes that changed since last sync
        query = select(Note).where(Note.user_id == user.id)
        
        if last_sync_at:
            # Get notes updated after last sync
            query = query.where(
                or_(
                    Note.updated_at > last_sync_at,
                    Note.synced_at > last_sync_at
                )
            )
        
        result = await self.db.execute(query)
        server_notes = result.scalars().all()
        
        await self.db.commit()
        
        return [NoteResponse.model_validate(note) for note in server_notes]
    
    async def sync_folders(
        self,
        user: User,
        client_folders: List[FolderSyncItem],
        last_sync_at: Optional[datetime]
    ) -> List[FolderResponse]:
        """
        Synchronize folders between client and server.
        
        Args:
            user: Current user
            client_folders: Folders from the client
            last_sync_at: Last sync timestamp from client
            
        Returns:
            List of folders that changed on server since last sync
        """
        sync_time = datetime.utcnow()
        
        # Process client folders
        for client_folder in client_folders:
            result = await self.db.execute(
                select(Folder).where(
                    Folder.id == client_folder.id,
                    Folder.user_id == user.id
                )
            )
            existing_folder = result.scalar_one_or_none()
            
            if existing_folder:
                if client_folder.updated_at > existing_folder.updated_at:
                    existing_folder.name = client_folder.name
                    existing_folder.color = client_folder.color
                    existing_folder.is_deleted = client_folder.is_deleted
                    existing_folder.updated_at = client_folder.updated_at
            else:
                if not client_folder.is_deleted:
                    new_folder = Folder(
                        id=client_folder.id,
                        user_id=user.id,
                        name=client_folder.name,
                        color=client_folder.color,
                        is_deleted=client_folder.is_deleted,
                        updated_at=client_folder.updated_at
                    )
                    self.db.add(new_folder)
        
        await self.db.flush()
        
        # Get server folders that changed
        query = select(Folder).where(Folder.user_id == user.id)
        
        if last_sync_at:
            query = query.where(Folder.updated_at > last_sync_at)
        
        result = await self.db.execute(query)
        server_folders = result.scalars().all()
        
        await self.db.commit()
        
        return [FolderResponse.model_validate(folder) for folder in server_folders]
