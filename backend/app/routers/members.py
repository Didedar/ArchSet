"""Dig-site membership: who else can reach a folder.

Only the owner may change the roster. That is the single thing separating an
owner from a member -- there are no other roles by design (spec section:
"Роли участников: нет").
"""

from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models.folder import Folder
from ..models.membership import FolderMember
from ..models.user import User
from ..utils.access import accessible_folder_ids
from ..utils.security import get_current_user

router = APIRouter(prefix="/folders", tags=["Members"])


class MemberInvite(BaseModel):
    """Invitations are addressed by email: it is what one archaeologist knows
    about another, whereas the user id is an implementation detail."""

    email: EmailStr


class MemberResponse(BaseModel):
    user_id: str
    email: str
    joined_at: datetime

    class Config:
        from_attributes = True


async def _owned_folder_or_403(
    folder_id: str, user: User, db: AsyncSession
) -> Folder:
    """The folder, if `user` owns it.

    A member gets 403 rather than 404: they can legitimately see the folder,
    they just cannot change who else does. Pretending it does not exist would
    be a worse lie than refusing.
    """
    result = await db.execute(select(Folder).where(Folder.id == folder_id))
    folder = result.scalar_one_or_none()
    if folder is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found"
        )
    if folder.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the owner of a dig site can manage its members",
        )
    return folder


@router.get("/{folder_id}/members", response_model=List[MemberResponse])
async def list_members(
    folder_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Everyone the folder is shared with. Owner or member may look."""
    accessible = await accessible_folder_ids(db, current_user)
    if folder_id not in accessible:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found"
        )

    result = await db.execute(
        select(FolderMember, User)
        .join(User, User.id == FolderMember.user_id)
        .where(FolderMember.folder_id == folder_id)
    )
    return [
        MemberResponse(
            user_id=member.user_id, email=user.email, joined_at=member.joined_at
        )
        for member, user in result.all()
    ]


@router.post(
    "/{folder_id}/members",
    response_model=MemberResponse,
    status_code=status.HTTP_201_CREATED,
)
async def invite_member(
    folder_id: str,
    invite: MemberInvite,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Grant someone access to a dig site.

    Requires a network connection by nature: there is no way to agree with the
    server about a new member without reaching the server. Done once in camp;
    everything after that works offline.
    """
    await _owned_folder_or_403(folder_id, current_user, db)

    result = await db.execute(select(User).where(User.email == invite.email))
    invitee = result.scalar_one_or_none()
    if invitee is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account with that email address",
        )

    if invitee.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already own this dig site",
        )

    existing = await db.execute(
        select(FolderMember).where(
            FolderMember.folder_id == folder_id,
            FolderMember.user_id == invitee.id,
        )
    )
    member = existing.scalar_one_or_none()
    if member is None:
        # Idempotent: inviting the same colleague twice is a no-op, not a
        # duplicate row or an error the UI has to explain.
        member = FolderMember(folder_id=folder_id, user_id=invitee.id)
        db.add(member)
        await db.flush()

    return MemberResponse(
        user_id=invitee.id, email=invitee.email, joined_at=member.joined_at
    )


@router.delete(
    "/{folder_id}/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def revoke_member(
    folder_id: str,
    user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove someone's access.

    Deliberately deletes only the membership. Whatever they wrote stays: an
    admin action by one person must never destroy another person's field
    notes.
    """
    await _owned_folder_or_403(folder_id, current_user, db)

    result = await db.execute(
        select(FolderMember).where(
            FolderMember.folder_id == folder_id,
            FolderMember.user_id == user_id,
        )
    )
    member = result.scalar_one_or_none()
    if member is not None:
        await db.delete(member)
        await db.flush()
