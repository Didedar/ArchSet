# Routers package
from .auth import router as auth_router
from .notes import router as notes_router
from .folders import router as folders_router
from .sync import router as sync_router
from .gemini import router as gemini_router
from .ai import router as ai_router

__all__ = [
    "auth_router",
    "notes_router",
    "folders_router",
    "sync_router",
    "gemini_router",
]
