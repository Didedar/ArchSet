"""
AI Chat API endpoints.
"""

from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from ..services.rag_service import rag_service
from ..utils.security import get_current_user
from ..models.user import User

router = APIRouter(prefix="/ai", tags=["AI Chat"])


class ChatRequest(BaseModel):
    query: str
    history: List[Dict[str, Any]] = []


class ChatResponse(BaseModel):
    response: str
    success: bool
    error: str = None


@router.post("/chat", response_model=ChatResponse)
async def chat_with_diary(
    request: ChatRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Chat with the user's diary using RAG.
    """
    if not request.query.strip():
        raise HTTPException(status_code=400, detail="Query cannot be empty")
        
    try:
        response_text = await rag_service.chat_with_diary(
            user_query=request.query,
            chat_history=request.history,
            user_id=current_user.id
        )
        
        return ChatResponse(
            response=response_text,
            success=True
        )
    except Exception as e:
        return ChatResponse(
            response="",
            success=False,
            error=str(e)
        )
