"""
Note database model for diary entries.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Note(Base):
    """Note model for diary entries."""
    
    __tablename__ = "notes"
    
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
    
    def __repr__(self) -> str:
        return f"<Note(id={self.id}, title={self.title[:30] if self.title else 'Untitled'})>"
