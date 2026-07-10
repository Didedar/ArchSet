import asyncio
import sys
import os

# Ensure backend directory is in python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.services.rag_service import rag_service


async def check_rag_index():
    """
    Inspect the local file-based RAG vector store (./storage) that
    RAGService actually uses. Reports node counts per user/note so
    duplicate or missing indexing can be spotted directly.
    """
    storage_path = rag_service.storage_path
    print(f"🔌 Checking local RAG vector store at '{storage_path}'...")

    docstore_path = os.path.join(storage_path, "docstore.json")
    if not os.path.exists(storage_path) or not os.path.exists(docstore_path):
        print(f"❌ '{docstore_path}' not found — index looks uninitialized.")
        print("   It's created automatically on backend startup (RAGService.initialize()).")
        return

    print(f"✅ Found storage at '{storage_path}'.")

    try:
        index = rag_service._get_index()
    except Exception as e:
        print(f"❌ Failed to load index: {e}")
        return

    docs = index.docstore.docs
    print(f"📊 Indexed nodes: {len(docs)}")

    if not docs:
        print("ℹ️  No nodes indexed yet. Chat will reply that no diary entries are available.")
        return

    by_user = {}
    by_note = {}
    for node in docs.values():
        user_id = node.metadata.get("user_id", "<unknown>")
        note_id = node.metadata.get("note_id", "<unknown>")
        by_user[user_id] = by_user.get(user_id, 0) + 1
        by_note[note_id] = by_note.get(note_id, 0) + 1

    print(f"👤 Distinct users with indexed notes: {len(by_user)}")
    for user_id, count in sorted(by_user.items(), key=lambda kv: -kv[1]):
        print(f"   {user_id}: {count} node(s)")

    duplicated_notes = {note_id: c for note_id, c in by_note.items() if c > 1}
    if duplicated_notes:
        print(
            f"⚠️  {len(duplicated_notes)} note_id(s) have more than one node. "
            "This is expected if a long note was chunked into several nodes; "
            "if a short note shows a high count, it likely means duplicates "
            "were indexed before sync_diary_to_vector_db switched to update_ref_doc:"
        )
        for note_id, count in sorted(duplicated_notes.items(), key=lambda kv: -kv[1])[:10]:
            print(f"   note_id={note_id}: {count} node(s)")
    else:
        print("✅ No note_id has more than one node — no duplicate indexing detected.")


if __name__ == "__main__":
    asyncio.run(check_rag_index())
