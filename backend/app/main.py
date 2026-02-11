"""
ArchSet Backend - FastAPI Application

Main entry point for the ArchSet diary application backend.
Provides authentication, notes/folders management, and Gemini AI services.
"""

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .config import get_settings
from .database import init_db
from .services.rag_service import rag_service
from .routers import (
    auth_router,
    notes_router,
    folders_router,
    sync_router,
    gemini_router,
    ai_router,
)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle management."""
    # Startup: Initialize database
    await init_db()
    
    # Initialize RAG Service (Vector DB setup)
    await rag_service.initialize()
    
    # Ensure Whisper model is downloaded (if online)
    from .services.whisper_service import WhisperService
    # Run in thread pool to not block async loop if it takes time (though it's startup)
    import asyncio
    try:
        await asyncio.to_thread(WhisperService.ensure_model_downloaded)
    except Exception as e:
        print(f"Startup warning: Whisper model check failed: {e}")
    
    # Create upload directory if it doesn't exist
    os.makedirs(settings.upload_dir, exist_ok=True)
    
    print(f"🚀 ArchSet Backend started on {settings.host}:{settings.port}")
    print(f"📚 API docs available at http://{settings.host}:{settings.port}/docs")
    
    yield
    
    # Shutdown
    print("👋 ArchSet Backend shutting down...")


# Create FastAPI app
app = FastAPI(
    title="ArchSet API",
    description="""
    Backend API for the ArchSet archaeological diary mobile application.
    
    ## Features
    
    - **Authentication**: JWT-based user authentication
    - **Notes**: Create, read, update, delete diary entries
    - **Folders**: Organize notes into folders
    - **Sync**: Offline-first synchronization
    - **Gemini AI**: Audio transcription and archaeological text rewriting
    """,
    version="1.0.0",
    lifespan=lifespan,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify allowed origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
API_PREFIX = "/api/v1"

app.include_router(auth_router, prefix=API_PREFIX)
app.include_router(notes_router, prefix=API_PREFIX)
app.include_router(folders_router, prefix=API_PREFIX)
app.include_router(sync_router, prefix=API_PREFIX)
app.include_router(gemini_router, prefix=API_PREFIX)
app.include_router(ai_router, prefix=API_PREFIX)


@app.get("/")
async def root():
    """Root endpoint - API status check."""
    return {
        "name": "ArchSet API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring."""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug
    )
