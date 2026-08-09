"""Tests for /api/v1/gemini: transcribe, rewrite, analyze-image, ocr.

GeminiService is DI-injected via Depends(get_gemini_service), so these tests
override that dependency with a fake instead of constructing the real
service (which would need a live Gemini API key to do anything useful).
"""

from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.main import app
from app.services.gemini_service import get_gemini_service


@pytest.fixture
def fake_gemini():
    fake = AsyncMock()
    app.dependency_overrides[get_gemini_service] = lambda: fake
    yield fake
    # pop, not del: the `client` fixture's own teardown does a blanket
    # .clear() of all overrides, and fixture teardown order isn't
    # guaranteed relative to this one -- del would raise KeyError if
    # client's clear() already ran first.
    app.dependency_overrides.pop(get_gemini_service, None)


@pytest.mark.asyncio
async def test_transcribe_returns_the_transcribed_text(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.transcribe_audio_bytes.return_value = "Found a shard at 2m depth."

    response = await client.post(
        "/api/v1/gemini/transcribe",
        files={"file": ("recording.m4a", b"fake-audio-bytes", "audio/mp4")},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["text"] == "Found a shard at 2m depth."


@pytest.mark.asyncio
async def test_transcribe_rejects_an_unsupported_file_type(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    response = await client.post(
        "/api/v1/gemini/transcribe",
        files={"file": ("recording.txt", b"not audio", "text/plain")},
        headers=auth_headers,
    )

    assert response.status_code == 400
    fake_gemini.transcribe_audio_bytes.assert_not_called()


@pytest.mark.asyncio
async def test_transcribe_reports_failure_when_no_text_is_returned(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.transcribe_audio_bytes.return_value = None

    response = await client.post(
        "/api/v1/gemini/transcribe",
        files={"file": ("recording.m4a", b"fake-audio-bytes", "audio/mp4")},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is False
    assert body["error"]


@pytest.mark.asyncio
async def test_transcribe_reports_a_value_error_as_a_clean_failure(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.transcribe_audio_bytes.side_effect = ValueError("Gemini API key not configured")

    response = await client.post(
        "/api/v1/gemini/transcribe",
        files={"file": ("recording.m4a", b"fake-audio-bytes", "audio/mp4")},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is False
    assert "not configured" in body["error"]


@pytest.mark.asyncio
async def test_transcribe_works_without_auth(client: AsyncClient, fake_gemini):
    # Unlike rewrite/analyze-image/ocr below: transcribe is the app's default
    # transcription engine, so a guest who hasn't signed in yet still needs
    # it to work.
    fake_gemini.transcribe_audio_bytes.return_value = "Found a shard at 2m depth."

    response = await client.post(
        "/api/v1/gemini/transcribe",
        files={"file": ("recording.m4a", b"fake-audio-bytes", "audio/mp4")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["text"] == "Found a shard at 2m depth."


@pytest.mark.asyncio
async def test_rewrite_returns_the_rewritten_text(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.rewrite_for_archaeology.return_value = "Formal archaeological text."

    response = await client.post(
        "/api/v1/gemini/rewrite",
        json={"text": "found some pottery"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["rewritten_text"] == "Formal archaeological text."
    assert body["original_text"] == "found some pottery"


@pytest.mark.asyncio
async def test_rewrite_rejects_empty_text(client: AsyncClient, auth_headers: dict, fake_gemini):
    response = await client.post(
        "/api/v1/gemini/rewrite", json={"text": "   "}, headers=auth_headers
    )

    assert response.status_code == 400
    fake_gemini.rewrite_for_archaeology.assert_not_called()


@pytest.mark.asyncio
async def test_rewrite_reports_a_value_error_as_a_clean_failure(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.rewrite_for_archaeology.side_effect = ValueError("Gemini API key not configured")

    response = await client.post(
        "/api/v1/gemini/rewrite", json={"text": "some text"}, headers=auth_headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is False
    assert "not configured" in body["error"]


@pytest.mark.asyncio
async def test_analyze_image_returns_the_analysis(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.analyze_image_bytes.return_value = '{"material": "ceramic"}'

    response = await client.post(
        "/api/v1/gemini/analyze-image",
        files={"file": ("find.jpg", b"fake-image-bytes", "image/jpeg")},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["analysis"] == '{"material": "ceramic"}'


@pytest.mark.asyncio
async def test_analyze_image_forwards_optional_coordinates(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.analyze_image_bytes.return_value = "{}"

    await client.post(
        "/api/v1/gemini/analyze-image",
        files={"file": ("find.jpg", b"fake-image-bytes", "image/jpeg")},
        data={"latitude": "51.5", "longitude": "-0.1"},
        headers=auth_headers,
    )

    fake_gemini.analyze_image_bytes.assert_awaited_once()
    _, kwargs = fake_gemini.analyze_image_bytes.call_args
    assert kwargs["latitude"] == 51.5
    assert kwargs["longitude"] == -0.1


@pytest.mark.asyncio
async def test_analyze_image_rejects_an_unsupported_file_type(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    response = await client.post(
        "/api/v1/gemini/analyze-image",
        files={"file": ("find.txt", b"not an image", "text/plain")},
        headers=auth_headers,
    )

    assert response.status_code == 400


@pytest.mark.asyncio
async def test_ocr_returns_the_extracted_text(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    fake_gemini.extract_text_from_image.return_value = "Site register page 12"

    response = await client.post(
        "/api/v1/gemini/ocr",
        files={"file": ("page.png", b"fake-image-bytes", "image/png")},
        headers=auth_headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["text"] == "Site register page 12"


@pytest.mark.asyncio
async def test_ocr_rejects_an_unsupported_file_type(
    client: AsyncClient, auth_headers: dict, fake_gemini
):
    response = await client.post(
        "/api/v1/gemini/ocr",
        files={"file": ("page.bmp", b"not supported", "image/bmp")},
        headers=auth_headers,
    )

    assert response.status_code == 400
