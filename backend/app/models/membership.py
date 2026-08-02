"""Folder membership: who, besides the owner, can reach a dig site."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from ..database import Base


class FolderMember(Base):
    """A user granted access to a folder they do not own.

    The owner is NOT represented here -- ownership stays on `folders.user_id`.
    Access is "owner OR row in this table", expressed once in
    `app/utils/access.py` and nowhere else.
    """

    __tablename__ = "folder_members"

    folder_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("folders.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )

    def __repr__(self) -> str:
        return f"<FolderMember(folder_id={self.folder_id}, user_id={self.user_id})>"
