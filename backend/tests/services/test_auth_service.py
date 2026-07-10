"""Direct unit tests for AuthService, focused on behavior not already fully
exercised through tests/routers/test_auth.py's HTTP-level coverage -- in
particular, refresh_tokens' "user no longer exists" branch, which needs a
user deleted out from under a still-valid refresh token to reach.
"""

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.auth import UserLogin, UserRegister
from app.services.auth_service import AuthService
from app.utils.security import create_refresh_token


@pytest.mark.asyncio
async def test_register_stores_a_bcrypt_hash_not_the_plaintext_password(
    db_session: AsyncSession,
):
    service = AuthService(db_session)

    user = await service.register(
        UserRegister(email="new@example.com", password="password123")
    )

    stored = await db_session.get(User, user.id)
    assert stored.password_hash != "password123"
    assert stored.password_hash.startswith("$2b$")


@pytest.mark.asyncio
async def test_register_raises_400_for_a_duplicate_email(
    db_session: AsyncSession, test_user: User
):
    service = AuthService(db_session)

    with pytest.raises(HTTPException) as exc_info:
        await service.register(
            UserRegister(email=test_user.email, password="password123")
        )

    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_login_raises_401_for_wrong_password(db_session: AsyncSession, test_user: User):
    service = AuthService(db_session)

    with pytest.raises(HTTPException) as exc_info:
        await service.login(UserLogin(email=test_user.email, password="wrong"))

    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_login_returns_a_working_token_pair(db_session: AsyncSession, test_user: User):
    service = AuthService(db_session)

    token = await service.login(UserLogin(email=test_user.email, password="password123"))

    assert token.access_token
    assert token.refresh_token
    assert token.access_token != token.refresh_token


@pytest.mark.asyncio
async def test_refresh_tokens_raises_401_when_the_user_no_longer_exists(
    db_session: AsyncSession, test_user: User
):
    """A refresh token minted for a user who is later deleted (account
    deletion, admin action) must not still be honored.
    """
    service = AuthService(db_session)
    refresh_token = create_refresh_token(data={"sub": test_user.id})

    await db_session.delete(test_user)
    await db_session.commit()

    with pytest.raises(HTTPException) as exc_info:
        await service.refresh_tokens(refresh_token)

    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_refresh_tokens_returns_a_new_pair_for_a_valid_token(
    db_session: AsyncSession, test_user: User
):
    service = AuthService(db_session)
    refresh_token = create_refresh_token(data={"sub": test_user.id})

    token = await service.refresh_tokens(refresh_token)

    assert token.access_token
    assert token.refresh_token
