import asyncio
import sys
import os

# Ensure backend directory is in python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import engine, async_session_maker
from app.models.note import Note
from app.services.rag_service import rag_service
from sqlalchemy import select

async def reindex_all_notes():
    print("🔌 Connecting to database...")
    
    async with async_session_maker() as session:
        print("🔍 Fetching all non-deleted notes...")
        result = await session.execute(
            select(Note).where(Note.is_deleted == False)
        )
        notes = result.scalars().all()
        
        print(f"📄 Found {len(notes)} notes. Starting re-indexing...")
        
        # Initialize RAG (ensure storage exists)
        await rag_service.initialize()
        
        for i, note in enumerate(notes):
            if not note.content:
                continue
                
            try:
                print(f"   [{i+1}/{len(notes)}] Indexing note '{note.title}' (ID: {note.id})...")
                await rag_service.sync_diary_to_vector_db(
                    note_id=note.id,
                    text=note.content,
                    user_id=note.user_id,
                    title=note.title or "Untitled"
                )
            except Exception as e:
                print(f"❌ Failed to index note {note.id}: {e}")
                
        print("✅ Re-indexing complete! All notes are now in the local vector store.")

if __name__ == "__main__":
    try:
        asyncio.run(reindex_all_notes())
    except KeyboardInterrupt:
        print("\n🛑 Re-indexing interrupted.")
