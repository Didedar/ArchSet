"""
Artifact database models for geotagged archaeology photos and their comments.

Photo binaries stay on the device -- only metadata (path, GPS coordinates and
the Gemini analysis JSON) is persisted server-side so it can sync across a
user's devices.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean, ForeignKey, Text, Float, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Artifact(Base):
    """Artifact model for a geotagged archaeological photo."""

    __tablename__ = "artifacts"

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
    note_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("notes.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    image_path: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        default=""
    )
    latitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )
    longitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )
    analysis_result: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )
    captured_at: Mapped[datetime] = mapped_column(
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
    user = relationship("User", back_populates="artifacts")
    note = relationship("Note", back_populates="artifacts")
    comments = relationship(
        "ArtifactComment",
        back_populates="artifact",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Artifact(id={self.id}, image_path={self.image_path})>"


class ArtifactComment(Base):
    """User comment attached to an artifact."""

    __tablename__ = "artifact_comments"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4())
    )
    artifact_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("artifacts.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    body: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default=""
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
    artifact = relationship("Artifact", back_populates="comments")
    user = relationship("User", back_populates="artifact_comments")

    def __repr__(self) -> str:
        return f"<ArtifactComment(id={self.id}, artifact_id={self.artifact_id})>"
