"""
Folder database model for organizing notes.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean, ForeignKey, Index, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Folder(Base):
    """Folder model for organizing notes."""

    __tablename__ = "folders"

    # NOTE: create_all() does not add indexes to an already-existing table.
    # For an existing database, apply backend/scripts/add_indexes.sql instead.
    __table_args__ = (
        Index("ix_folders_user_id_updated_at", "user_id", "updated_at"),
        Index("ix_folders_user_id_created_at", "user_id", "created_at"),
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
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )
    color: Mapped[str] = mapped_column(
        String(20),
        default="#E8B731"
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
    is_deleted: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )
    
    # Relationships
    user = relationship("User", back_populates="folders")
    notes = relationship("Note", back_populates="folder")
    
    def __repr__(self) -> str:
        return f"<Folder(id={self.id}, name={self.name})>"
