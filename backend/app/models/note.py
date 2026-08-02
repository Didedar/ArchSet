"""
Note database model for diary entries.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean, ForeignKey, Text, Index, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Note(Base):
    """Note model for diary entries."""

    __tablename__ = "notes"

    # NOTE: create_all() does not add indexes to an already-existing table.
    # For an existing database, apply backend/scripts/add_indexes.sql instead.
    __table_args__ = (
        Index("ix_notes_user_id_date", "user_id", "date"),
        Index("ix_notes_user_id_is_deleted_date", "user_id", "is_deleted", "date"),
        Index("ix_notes_user_id_updated_at", "user_id", "updated_at"),
    )

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    folder_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("folders.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    title: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        default=""
    )
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default=""
    )
    audio_path: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True
    )
    date: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow
    )
    # Server-assigned optimistic-concurrency counter. Incremented on every
    # accepted write; clients send back the revision they based their edit on
    # so a conflict can be detected without trusting device clocks. Two phones
    # offline in the field for a week drift apart, and comparing timestamps
    # would silently pick the wrong winner.
    revision: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default="1",
        default=1
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )
    synced_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True
    )
    is_deleted: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )
    
    # Relationships
    user = relationship("User", back_populates="notes")
    folder = relationship("Folder", back_populates="notes")
    artifacts = relationship("Artifact", back_populates="note")
    
    def __repr__(self) -> str:
        return f"<Note(id={self.id}, title={self.title[:30] if self.title else 'Untitled'})>"
