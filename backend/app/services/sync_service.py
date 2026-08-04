"""
Sync service for handling offline-first synchronization.
"""

from datetime import datetime
from typing import List, Optional, Set
import os
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_

from ..models.note import Note
from ..models.folder import Folder
from ..models.membership import FolderMember
from ..models.user import User
from ..utils.access import accessible_folder_ids
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
    


    async def _unreachable_ids(self, model, client_ids, reachable_ids):
        """Ids the client sent that exist on the server but this user may not
        touch -- typically a dig site whose access was revoked while they were
        offline, still sitting in their local copy.

        These must be skipped, not created. The prefetch cannot see them, so
        without this they fall into the "new row" branch and the INSERT hits
        the primary key: a 500 that fails the WHOLE batch, every sync, until
        the stale row is manually cleared. One revoked folder would silently
        stop the person's own unrelated work from ever syncing again.
        """
        if not client_ids:
            return set()
        result = await self.db.execute(
            select(model.id).where(model.id.in_(client_ids))
        )
        return {row for row in result.scalars().all()} - set(reachable_ids)


    @staticmethod
    def _permitted_folder(folder_id, folder_ids):
        """The folder a note may actually be filed into.

        A client names its own `folder_id`, and nothing stops it naming a dig
        site it was never invited to -- which would deposit its text in
        someone else's site with no membership at all. An unreachable folder
        degrades to None (a private, unfiled note) rather than being honoured
        or rejected outright: the same shape as `_resolve_note_id`, which
        turns a dangling artifact reference into an unattached artifact
        instead of failing the whole sync.
        """
        if folder_id is None or folder_id in folder_ids:
            return folder_id
        return None

    async def _reachable(self, user: User):
        """The access rule, resolved once per sync call.

        Returns `(folder_ids, note_predicate, artifact_predicate)`. Every query
        below uses these instead of restating "owner or member" -- see
        app/utils/access.py for why that matters.
        """
        folder_ids = await accessible_folder_ids(self.db, user)
        # An unfiled note (folder_id IS NULL) has no dig site to be shared
        # through, so it matches only the authorship arm. That is deliberate:
        # spec section 1 keeps unfiled notes private.
        note_pred = or_(Note.user_id == user.id, Note.folder_id.in_(folder_ids))
        artifact_pred = or_(
            Artifact.user_id == user.id,
            Artifact.note_id.in_(select(Note.id).where(note_pred)),
        )
        return folder_ids, note_pred, artifact_pred

    async def _newly_shared(
        self, user: User, last_sync_at: Optional[datetime]
    ) -> Set[str]:
        """Dig sites this user gained access to since they last synced.

        Being invited changes nothing about the folder or its entries: they
        keep the `updated_at` they already had. So an incremental pull, which
        asks "what changed since I last looked?", answers "nothing" and the
        shared site never arrives -- the invitee sees an account with no trace
        of the invitation at all.

        The question that actually matters to a client is "what is newly
        *visible* to me", and membership is where that is recorded. Every pull
        below therefore unions its normal cutoff with everything reachable
        through a membership granted after that cutoff.
        """
        if last_sync_at is None:
            return set()  # a full pull already carries everything reachable

        result = await self.db.execute(
            select(FolderMember.folder_id).where(
                FolderMember.user_id == user.id,
                FolderMember.joined_at > last_sync_at,
            )
        )
        return set(result.scalars().all())

    @staticmethod
    def _notes_in(folder_ids):
        """Ids of every note filed under [folder_ids], as a subquery."""
        return select(Note.id).where(Note.folder_id.in_(folder_ids))

    @staticmethod
    def _artifacts_in(folder_ids):
        """Ids of every artifact hanging off those notes, as a subquery."""
        return select(Artifact.id).where(
            Artifact.note_id.in_(SyncService._notes_in(folder_ids))
        )

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
        conflicted_ids: List[str] = []
        folder_ids, note_pred, _ = await self._reachable(user)
        
        # Prefetch every note the client sent in a single query instead of
        # issuing one SELECT per item.
        client_note_ids = [client_note.id for client_note in client_notes]
        existing_notes = {}
        if client_note_ids:
            result = await self.db.execute(
                select(Note).where(Note.id.in_(client_note_ids), note_pred)
            )
            existing_notes = {note.id: note for note in result.scalars().all()}

        skip_ids = await self._unreachable_ids(
            Note, client_note_ids, existing_notes.keys()
        )

        # Process client notes
        for client_note in client_notes:
            if client_note.id in skip_ids:
                continue
            # Check if note exists
            existing_note = existing_notes.get(client_note.id)

            if existing_note:
                # Optimistic concurrency. A client that names the revision it
                # edited from only wins if that is still the current one --
                # checked BEFORE the timestamp comparison on purpose, because
                # a device whose clock runs fast (or that has been offline for
                # a week) would otherwise win a race it actually lost.
                stale = (
                    client_note.base_revision is not None
                    and client_note.base_revision != existing_note.revision
                )
                if stale:
                    # Keep the server's version; the client forks its own copy
                    # so neither edit is lost.
                    conflicted_ids.append(client_note.id)
                elif (
                    client_note.base_revision is not None
                    or client_note.updated_at > existing_note.updated_at
                ):
                    existing_note.title = client_note.title
                    existing_note.content = client_note.content
                    existing_note.folder_id = self._permitted_folder(
                        client_note.folder_id, folder_ids
                    )
                    existing_note.audio_path = client_note.audio_path
                    existing_note.date = client_note.date
                    existing_note.is_deleted = client_note.is_deleted
                    existing_note.updated_at = client_note.updated_at
                    existing_note.synced_at = sync_time
                    existing_note.revision = existing_note.revision + 1

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
                        folder_id=self._permitted_folder(
                            client_note.folder_id, folder_ids
                        ),
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
        query = select(Note).where(note_pred)
        
        if last_sync_at:
            # Updated since last sync, or newly reachable through an
            # invitation that did not touch the rows themselves.
            newly_shared = await self._newly_shared(user, last_sync_at)
            query = query.where(
                or_(
                    Note.updated_at > last_sync_at,
                    Note.synced_at > last_sync_at,
                    Note.folder_id.in_(newly_shared),
                )
            )
        
        result = await self.db.execute(query)
        server_notes = list(result.scalars().all())

        # A conflicted note may not have changed since last_sync_at, in which
        # case the query above misses it -- and the client would have no
        # server version to keep beside its fork. Union them in explicitly.
        if conflicted_ids:
            already = {note.id for note in server_notes}
            missing = [cid for cid in conflicted_ids if cid not in already]
            if missing:
                extra = await self.db.execute(
                    select(Note).where(Note.id.in_(missing), note_pred)
                )
                server_notes.extend(extra.scalars().all())

        await self.db.commit()

        return (
            [NoteResponse.model_validate(note) for note in server_notes],
            conflicted_ids,
        )
    
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
        folder_ids, _, _ = await self._reachable(user)
        sync_time = datetime.utcnow()
        
        # Prefetch every folder the client sent in a single query instead of
        # issuing one SELECT per item.
        client_folder_ids = [client_folder.id for client_folder in client_folders]
        existing_folders = {}
        if client_folder_ids:
            result = await self.db.execute(
                select(Folder).where(
                    Folder.id.in_(client_folder_ids),
                    Folder.id.in_(folder_ids),
                )
            )
            existing_folders = {folder.id: folder for folder in result.scalars().all()}

        skip_folder_ids = await self._unreachable_ids(
            Folder, client_folder_ids, existing_folders.keys()
        )

        # Process client folders
        for client_folder in client_folders:
            if client_folder.id in skip_folder_ids:
                continue
            existing_folder = existing_folders.get(client_folder.id)

            if existing_folder:
                # Same revision guard as notes, but a mismatch is dropped
                # silently rather than reported: forking a dig site would
                # leave two where there was one, which is worse than a lost
                # rename.
                if (
                    client_folder.base_revision is not None
                    and client_folder.base_revision != existing_folder.revision
                ):
                    continue
                if (
                    client_folder.base_revision is not None
                    or client_folder.updated_at > existing_folder.updated_at
                ):
                    existing_folder.name = client_folder.name
                    existing_folder.color = client_folder.color
                    existing_folder.is_deleted = client_folder.is_deleted
                    existing_folder.updated_at = client_folder.updated_at
                    existing_folder.revision = existing_folder.revision + 1
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
        
        # Re-resolve: the set above was computed before this request's own
        # new folders existed, so a folder the client just created would be
        # missing from its own sync response.
        folder_ids = await accessible_folder_ids(self.db, user)

        # Get server folders that changed
        query = select(Folder).where(Folder.id.in_(folder_ids))
        
        if last_sync_at:
            newly_shared = await self._newly_shared(user, last_sync_at)
            query = query.where(
                or_(
                    Folder.updated_at > last_sync_at,
                    Folder.id.in_(newly_shared),
                )
            )
        
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

        _, note_pred, _ = await self._reachable(user)
        result = await self.db.execute(
            select(Note.id).where(Note.id == note_id, note_pred)
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
        folder_ids, note_pred, artifact_pred = await self._reachable(user)
        sync_time = datetime.utcnow()

        # Process client artifacts
        for client_artifact in client_artifacts:
            result = await self.db.execute(
                select(Artifact).where(
                    Artifact.id == client_artifact.id, artifact_pred
                )
            )
            existing_artifact = result.scalar_one_or_none()

            if existing_artifact:
                # Update if client version is newer
                # Same revision guard as notes, but a mismatch is dropped
                # silently rather than reported: forking an artifact would double-count a physical
                # find on the map.
                if (
                    client_artifact.base_revision is not None
                    and client_artifact.base_revision != existing_artifact.revision
                ):
                    continue
                if (
                    client_artifact.base_revision is not None
                    or client_artifact.updated_at > existing_artifact.updated_at
                ):
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
                    existing_artifact.revision = existing_artifact.revision + 1
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
        query = select(Artifact).where(artifact_pred)

        if last_sync_at:
            newly_shared = await self._newly_shared(user, last_sync_at)
            query = query.where(
                or_(
                    Artifact.updated_at > last_sync_at,
                    Artifact.synced_at > last_sync_at,
                    Artifact.note_id.in_(self._notes_in(newly_shared)),
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
        folder_ids, note_pred, artifact_pred = await self._reachable(user)
        sync_time = datetime.utcnow()

        # Process client comments
        for client_comment in client_comments:
            result = await self.db.execute(
                select(ArtifactComment).where(
                    ArtifactComment.id == client_comment.id,
                    or_(
                        ArtifactComment.user_id == user.id,
                        ArtifactComment.artifact_id.in_(
                            select(Artifact.id).where(artifact_pred)
                        ),
                    ),
                )
            )
            existing_comment = result.scalar_one_or_none()

            if existing_comment:
                # Same revision guard as notes, but a mismatch is dropped
                # silently rather than reported: comments are append-only, so this is
                # effectively unreachable; kept for uniformity.
                if (
                    client_comment.base_revision is not None
                    and client_comment.base_revision != existing_comment.revision
                ):
                    continue
                if (
                    client_comment.base_revision is not None
                    or client_comment.updated_at > existing_comment.updated_at
                ):
                    existing_comment.body = client_comment.body
                    existing_comment.is_deleted = client_comment.is_deleted
                    existing_comment.updated_at = client_comment.updated_at
                    existing_comment.synced_at = sync_time
                    existing_comment.revision = existing_comment.revision + 1
            else:
                if not client_comment.is_deleted:
                    # Skip comments whose parent artifact this user doesn't
                    # have on the server -- inserting would violate the FK.
                    artifact_result = await self.db.execute(
                        select(Artifact.id).where(
                            Artifact.id == client_comment.artifact_id,
                            artifact_pred,
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
        query = select(ArtifactComment).where(
            or_(
                ArtifactComment.user_id == user.id,
                ArtifactComment.artifact_id.in_(
                    select(Artifact.id).where(artifact_pred)
                ),
            )
        )

        if last_sync_at:
            newly_shared = await self._newly_shared(user, last_sync_at)
            query = query.where(
                or_(
                    ArtifactComment.updated_at > last_sync_at,
                    ArtifactComment.synced_at > last_sync_at,
                    ArtifactComment.artifact_id.in_(
                        self._artifacts_in(newly_shared)
                    ),
                )
            )

        result = await self.db.execute(query)
        server_comments = result.scalars().all()

        await self.db.commit()

        return [ArtifactCommentResponse.model_validate(c) for c in server_comments]
