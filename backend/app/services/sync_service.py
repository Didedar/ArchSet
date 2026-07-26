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
from ..models.artifact import Artifact, ArtifactComment
from ..schemas.note import NoteSyncItem, NoteResponse
from ..schemas.folder import FolderSyncItem, FolderResponse
from ..schemas.artifact import (
    ArtifactSyncItem,
    ArtifactResponse,
    ArtifactCommentSyncItem,
    ArtifactCommentResponse,
)


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
        
        # Prefetch every note the client sent in a single query instead of
        # issuing one SELECT per item.
        client_note_ids = [client_note.id for client_note in client_notes]
        existing_notes = {}
        if client_note_ids:
            result = await self.db.execute(
                select(Note).where(
                    Note.id.in_(client_note_ids),
                    Note.user_id == user.id
                )
            )
            existing_notes = {note.id: note for note in result.scalars().all()}

        # Process client notes
        for client_note in client_notes:
            # Check if note exists
            existing_note = existing_notes.get(client_note.id)

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
                        if background_tasks:
                            background_tasks.add_task(
                                rag_service.delete_note_from_index,
                                note_id=existing_note.id
                            )
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
                    # Keep the lookup in sync so a duplicated id later in the
                    # same batch resolves to the note just created.
                    existing_notes[new_note.id] = new_note
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
        
        # Prefetch every folder the client sent in a single query instead of
        # issuing one SELECT per item.
        client_folder_ids = [client_folder.id for client_folder in client_folders]
        existing_folders = {}
        if client_folder_ids:
            result = await self.db.execute(
                select(Folder).where(
                    Folder.id.in_(client_folder_ids),
                    Folder.user_id == user.id
                )
            )
            existing_folders = {folder.id: folder for folder in result.scalars().all()}

        # Process client folders
        for client_folder in client_folders:
            existing_folder = existing_folders.get(client_folder.id)

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
                    # Keep the lookup in sync so a duplicated id later in the
                    # same batch resolves to the folder just created.
                    existing_folders[new_folder.id] = new_folder

        await self.db.flush()
        
        # Get server folders that changed
        query = select(Folder).where(Folder.user_id == user.id)
        
        if last_sync_at:
            query = query.where(Folder.updated_at > last_sync_at)
        
        result = await self.db.execute(query)
        server_folders = result.scalars().all()

        await self.db.commit()

        return [FolderResponse.model_validate(folder) for folder in server_folders]

    async def _resolve_note_id(self, user: User, note_id: Optional[str]) -> Optional[str]:
        """Return note_id only if that note actually exists for this user.

        An artifact can reference a note the server has not seen yet (the
        client may have created both offline). Artifacts are synced after
        notes in the same request, which usually resolves this, but a
        dangling reference must not turn into a foreign-key violation that
        fails the whole sync -- so it degrades to an unattached artifact.
        """
        if note_id is None:
            return None

        result = await self.db.execute(
            select(Note.id).where(
                Note.id == note_id,
                Note.user_id == user.id
            )
        )
        return result.scalar_one_or_none()

    async def sync_artifacts(
        self,
        user: User,
        client_artifacts: List[ArtifactSyncItem],
        last_sync_at: Optional[datetime]
    ) -> List[ArtifactResponse]:
        """
        Synchronize artifacts (geotagged photos) between client and server.

        Uses "last write wins" conflict resolution. Photo binaries stay on
        the device; only metadata is stored here.

        Args:
            user: Current user
            client_artifacts: Artifacts from the client
            last_sync_at: Last sync timestamp from client

        Returns:
            List of artifacts that changed on server since last sync
        """
        sync_time = datetime.utcnow()

        # Process client artifacts
        for client_artifact in client_artifacts:
            result = await self.db.execute(
                select(Artifact).where(
                    Artifact.id == client_artifact.id,
                    Artifact.user_id == user.id
                )
            )
            existing_artifact = result.scalar_one_or_none()

            if existing_artifact:
                # Update if client version is newer
                if client_artifact.updated_at > existing_artifact.updated_at:
                    existing_artifact.note_id = await self._resolve_note_id(
                        user, client_artifact.note_id
                    )
                    existing_artifact.image_path = client_artifact.image_path
                    existing_artifact.latitude = client_artifact.latitude
                    existing_artifact.longitude = client_artifact.longitude
                    existing_artifact.analysis_result = client_artifact.analysis_result
                    existing_artifact.captured_at = client_artifact.captured_at
                    existing_artifact.is_deleted = client_artifact.is_deleted
                    existing_artifact.updated_at = client_artifact.updated_at
                    existing_artifact.synced_at = sync_time
            else:
                # Create new artifact
                if not client_artifact.is_deleted:
                    new_artifact = Artifact(
                        id=client_artifact.id,
                        user_id=user.id,
                        note_id=await self._resolve_note_id(
                            user, client_artifact.note_id
                        ),
                        image_path=client_artifact.image_path,
                        latitude=client_artifact.latitude,
                        longitude=client_artifact.longitude,
                        analysis_result=client_artifact.analysis_result,
                        captured_at=client_artifact.captured_at,
                        is_deleted=client_artifact.is_deleted,
                        updated_at=client_artifact.updated_at,
                        synced_at=sync_time
                    )
                    self.db.add(new_artifact)

        await self.db.flush()

        # Get server artifacts that changed since last sync
        query = select(Artifact).where(Artifact.user_id == user.id)

        if last_sync_at:
            query = query.where(
                or_(
                    Artifact.updated_at > last_sync_at,
                    Artifact.synced_at > last_sync_at
                )
            )

        result = await self.db.execute(query)
        server_artifacts = result.scalars().all()

        await self.db.commit()

        return [ArtifactResponse.model_validate(a) for a in server_artifacts]

    async def sync_artifact_comments(
        self,
        user: User,
        client_comments: List[ArtifactCommentSyncItem],
        last_sync_at: Optional[datetime]
    ) -> List[ArtifactCommentResponse]:
        """
        Synchronize artifact comments between client and server.

        Uses "last write wins" conflict resolution. Must run *after*
        sync_artifacts, since a comment can only be stored once its parent
        artifact exists. A comment whose artifact is still unknown to the
        server is skipped rather than failing the whole sync.

        Args:
            user: Current user
            client_comments: Artifact comments from the client
            last_sync_at: Last sync timestamp from client

        Returns:
            List of artifact comments that changed on server since last sync
        """
        sync_time = datetime.utcnow()

        # Process client comments
        for client_comment in client_comments:
            result = await self.db.execute(
                select(ArtifactComment).where(
                    ArtifactComment.id == client_comment.id,
                    ArtifactComment.user_id == user.id
                )
            )
            existing_comment = result.scalar_one_or_none()

            if existing_comment:
                if client_comment.updated_at > existing_comment.updated_at:
                    existing_comment.body = client_comment.body
                    existing_comment.is_deleted = client_comment.is_deleted
                    existing_comment.updated_at = client_comment.updated_at
                    existing_comment.synced_at = sync_time
            else:
                if not client_comment.is_deleted:
                    # Skip comments whose parent artifact this user doesn't
                    # have on the server -- inserting would violate the FK.
                    artifact_result = await self.db.execute(
                        select(Artifact.id).where(
                            Artifact.id == client_comment.artifact_id,
                            Artifact.user_id == user.id
                        )
                    )
                    if artifact_result.scalar_one_or_none() is None:
                        continue

                    new_comment = ArtifactComment(
                        id=client_comment.id,
                        artifact_id=client_comment.artifact_id,
                        user_id=user.id,
                        body=client_comment.body,
                        created_at=client_comment.created_at,
                        is_deleted=client_comment.is_deleted,
                        updated_at=client_comment.updated_at,
                        synced_at=sync_time
                    )
                    self.db.add(new_comment)

        await self.db.flush()

        # Get server comments that changed since last sync
        query = select(ArtifactComment).where(ArtifactComment.user_id == user.id)

        if last_sync_at:
            query = query.where(
                or_(
                    ArtifactComment.updated_at > last_sync_at,
                    ArtifactComment.synced_at > last_sync_at
                )
            )

        result = await self.db.execute(query)
        server_comments = result.scalars().all()

        await self.db.commit()

        return [ArtifactCommentResponse.model_validate(c) for c in server_comments]
