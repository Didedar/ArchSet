"""
Folder database model for organizing notes.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Folder(Base):
    """Folder model for organizing notes."""
    
    __tablename__ = "folders"
    
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
