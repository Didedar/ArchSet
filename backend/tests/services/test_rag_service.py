"""Unit tests for RAGService against a real (temp-dir-backed) llama-index
vector store, using the MockLLM/MockEmbedding stand-ins conftest installs
in place of the real Gemini-backed classes -- so these exercise real
index/persist/query behavior, not mocked-call-shape assertions, without any
network access.

Every test builds its own fresh RAGService() (not the `rag_service`
singleton, which the autouse _stub_rag_background_tasks fixture patches)
and redirects storage_path to pytest's tmp_path, so nothing here ever
touches the real ./storage directory.
"""

import pytest

from app.services.rag_service import RAGService


def _service(tmp_path) -> RAGService:
    service = RAGService()
    service.storage_path = str(tmp_path / "storage")
    return service


def _indexed_note_ids(index) -> set:
    """sync_diary_to_vector_db's Document gets split into child TextNodes by
    llama-index's node parser, so docstore.docs is keyed by auto-generated
    node ids, not note_id -- note_id only survives in each node's metadata.
    """
    return {doc.metadata.get("note_id") for doc in index.docstore.docs.values()}


@pytest.mark.asyncio
async def test_initialize_creates_the_storage_directory(tmp_path):
    service = _service(tmp_path)

    await service.initialize()

    assert (tmp_path / "storage").exists()
    assert (tmp_path / "storage" / "docstore.json").exists()


@pytest.mark.asyncio
async def test_initialize_does_not_raise_if_storage_already_exists(tmp_path):
    service = _service(tmp_path)
    await service.initialize()

    await service.initialize()  # must not raise on the already-exists path


@pytest.mark.asyncio
async def test_sync_diary_to_vector_db_indexes_the_note(tmp_path):
    service = _service(tmp_path)
    await service.initialize()

    await service.sync_diary_to_vector_db(
        note_id="note-1", text="Found pottery at trench 3", user_id="user-1", title="Day 1"
    )

    index = service._get_index()
    assert "note-1" in _indexed_note_ids(index)


@pytest.mark.asyncio
async def test_sync_diary_to_vector_db_replacing_the_same_note_id_does_not_duplicate(tmp_path):
    service = _service(tmp_path)
    await service.initialize()

    await service.sync_diary_to_vector_db(
        note_id="note-1", text="First version", user_id="user-1", title="Day 1"
    )
    await service.sync_diary_to_vector_db(
        note_id="note-1", text="Edited version", user_id="user-1", title="Day 1"
    )

    index = service._get_index()
    matching_docs = [
        doc for doc in index.docstore.docs.values() if doc.metadata.get("note_id") == "note-1"
    ]
    assert len(matching_docs) == 1
    assert matching_docs[0].text == "Edited version"


@pytest.mark.asyncio
async def test_delete_note_from_index_removes_the_note(tmp_path):
    service = _service(tmp_path)
    await service.initialize()
    await service.sync_diary_to_vector_db(
        note_id="note-1", text="Found pottery", user_id="user-1", title="Day 1"
    )
    assert "note-1" in _indexed_note_ids(service._get_index())  # confirms setup worked

    await service.delete_note_from_index("note-1")

    index = service._get_index()
    assert "note-1" not in _indexed_note_ids(index)


@pytest.mark.asyncio
async def test_delete_note_from_index_does_not_raise_for_an_unknown_note_id(tmp_path):
    service = _service(tmp_path)
    await service.initialize()

    await service.delete_note_from_index("never-indexed")  # must not raise


@pytest.mark.asyncio
async def test_chat_with_diary_returns_a_specific_message_when_nothing_is_indexed(tmp_path):
    service = _service(tmp_path)
    await service.initialize()

    response = await service.chat_with_diary(
        user_query="What did I find?", chat_history=[], user_id="user-1"
    )

    assert response == "I don't have any diary entries indexed yet. Please write some notes first!"


@pytest.mark.asyncio
async def test_chat_with_diary_returns_a_clean_error_message_on_failure(tmp_path, monkeypatch):
    service = _service(tmp_path)
    await service.initialize()
    await service.sync_diary_to_vector_db(
        note_id="note-1", text="Found pottery", user_id="user-1", title="Day 1"
    )

    def broken_get_index():
        raise RuntimeError("disk read error")

    monkeypatch.setattr(service, "_get_index", broken_get_index)

    response = await service.chat_with_diary(
        user_query="What did I find?", chat_history=[], user_id="user-1"
    )

    assert response == "I'm sorry, I encountered an error while accessing your diary: disk read error"


@pytest.mark.asyncio
async def test_chat_with_diary_returns_a_response_when_content_is_indexed(tmp_path):
    service = _service(tmp_path)
    await service.initialize()
    await service.sync_diary_to_vector_db(
        note_id="note-1", text="Found pottery at trench 3", user_id="user-1", title="Day 1"
    )

    response = await service.chat_with_diary(
        user_query="What did I find?",
        chat_history=[{"role": "user", "content": "Hi"}],
        user_id="user-1",
    )

    assert isinstance(response, str)
    assert response != ""
