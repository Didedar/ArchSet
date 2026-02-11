"""
Gemini AI API endpoints for transcription and text rewriting.
"""

import os
import aiofiles
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional

from ..services.gemini_service import get_gemini_service, GeminiService
from ..utils.security import get_current_user
from ..models.user import User
from ..config import get_settings

settings = get_settings()

router = APIRouter(prefix="/gemini", tags=["Gemini AI"])


class TranscriptionResponse(BaseModel):
    """Response for audio transcription."""
    text: Optional[str] = None
    success: bool
    error: Optional[str] = None


class RewriteRequest(BaseModel):
    """Request for text rewriting."""
    text: str


class RewriteResponse(BaseModel):
    """Response for text rewriting."""
    original_text: str
    rewritten_text: Optional[str] = None
    success: bool
    error: Optional[str] = None


class ImageAnalysisResponse(BaseModel):
    """Response for image analysis."""
    analysis: Optional[str] = None # JSON string
    success: bool
    error: Optional[str] = None


@router.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe_audio(
    file: UploadFile = File(..., description="Audio file to transcribe"),
    current_user: User = Depends(get_current_user),
    gemini: GeminiService = Depends(get_gemini_service)
):
    """
    Transcribe an audio file to text using Gemini AI.
    
    Supported formats: .m4a, .mp3, .wav, .webm, .ogg
    
    Maximum file size: 50MB
    """
    # Validate file type
    allowed_extensions = {".m4a", ".mp3", ".wav", ".webm", ".ogg"}
    file_ext = os.path.splitext(file.filename)[1].lower() if file.filename else ""
    
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    # Check file size
    max_size = settings.max_upload_size_mb * 1024 * 1024
    content = await file.read()
    
    if len(content) > max_size:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size: {settings.max_upload_size_mb}MB"
        )
    
    # Determine MIME type
    mime_types = {
        ".m4a": "audio/mp4",
        ".mp3": "audio/mpeg",
        ".wav": "audio/wav",
        ".webm": "audio/webm",
        ".ogg": "audio/ogg",
    }
    mime_type = mime_types.get(file_ext, "audio/mpeg")
    
    try:
        # Transcribe using Gemini
        text = await gemini.transcribe_audio_bytes(content, mime_type)
        
        if text:
            return TranscriptionResponse(text=text, success=True)
        else:
            return TranscriptionResponse(
                success=False,
                error="Transcription failed - no text returned"
            )
    except ValueError as e:
        return TranscriptionResponse(success=False, error=str(e))
    except Exception as e:
        return TranscriptionResponse(
            success=False,
            error=f"Transcription error: {str(e)}"
        )


@router.post("/rewrite", response_model=RewriteResponse)
async def rewrite_text(
    request: RewriteRequest,
    current_user: User = Depends(get_current_user),
    gemini: GeminiService = Depends(get_gemini_service)
):
    """
    Rewrite text according to archaeological field documentation standards.
    
    The AI will format the text using professional archaeological terminology,
    proper structure, and objective language.
    """
    if not request.text.strip():
        raise HTTPException(
            status_code=400,
            detail="Text cannot be empty"
        )
    
    try:
        rewritten = await gemini.rewrite_for_archaeology(request.text)
        
        if rewritten:
            return RewriteResponse(
                original_text=request.text,
                rewritten_text=rewritten,
                success=True
            )
        else:
            return RewriteResponse(
                original_text=request.text,
                success=False,
                error="Rewriting failed - no text returned"
            )
    except ValueError as e:
        return RewriteResponse(
            original_text=request.text,
            success=False,
            error=str(e)
        )
        return RewriteResponse(
            original_text=request.text,
            success=False,
            error=f"Rewrite error: {str(e)}"
        )


@router.post("/analyze-image", response_model=ImageAnalysisResponse)
async def analyze_image(
    file: UploadFile = File(..., description="Image file to analyze"),
    latitude: Optional[float] = Form(None),
    longitude: Optional[float] = Form(None),
    current_user: User = Depends(get_current_user),
    gemini: GeminiService = Depends(get_gemini_service)
):
    """
    Analyze an archaeological image using Gemini AI.
    
    Extracts spatial, physical, relational, and administrative context.
    Optionally providing latitude and longitude helps refine the spatial context.
    """
    # Validate file type
    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp", ".heic"}
    file_ext = os.path.splitext(file.filename)[1].lower() if file.filename else ""
    
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    # Check file size (reuse settings max size)
    max_size = settings.max_upload_size_mb * 1024 * 1024
    content = await file.read()
    
    if len(content) > max_size:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size: {settings.max_upload_size_mb}MB"
        )
    
    # Determine MIME type
    mime_types = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
        ".heic": "image/heic",
    }
    mime_type = mime_types.get(file_ext, "image/jpeg")
    
    try:
        analysis_json = await gemini.analyze_image_bytes(
            content, 
            mime_type,
            latitude=latitude,
            longitude=longitude
        )
        
        if analysis_json:
            return ImageAnalysisResponse(analysis=analysis_json, success=True)
        else:
            return ImageAnalysisResponse(
                success=False,
                error="Analysis failed - no data returned"
            )
    except ValueError as e:
        return ImageAnalysisResponse(success=False, error=str(e))
    except Exception as e:
        return ImageAnalysisResponse(
            success=False,
            error=f"Analysis error: {str(e)}"
        )


@router.post("/ocr", response_model=TranscriptionResponse)
async def extract_text(
    file: UploadFile = File(..., description="Image file to scan"),
    current_user: User = Depends(get_current_user),
    gemini: GeminiService = Depends(get_gemini_service)
):
    """
    Extract text from an image (OCR).
    """
    # Validate file type
    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp", ".heic"}
    file_ext = os.path.splitext(file.filename)[1].lower() if file.filename else ""
    
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    # Check file size (reuse settings max size)
    max_size = settings.max_upload_size_mb * 1024 * 1024
    content = await file.read()
    
    if len(content) > max_size:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size: {settings.max_upload_size_mb}MB"
        )
    
    # Determine MIME type
    mime_types = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
        ".heic": "image/heic",
    }
    mime_type = mime_types.get(file_ext, "image/jpeg")
    
    try:
        text = await gemini.extract_text_from_image(content, mime_type)
        
        if text:
            return TranscriptionResponse(text=text, success=True)
        else:
            return TranscriptionResponse(
                success=False,
                error="OCR failed - no text returned"
            )
    except ValueError as e:
        return TranscriptionResponse(success=False, error=str(e))
    except Exception as e:
        return TranscriptionResponse(
            success=False,
            error=f"OCR error: {str(e)}"
        )
