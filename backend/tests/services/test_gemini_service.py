"""Unit tests for GeminiService: online Gemini path plus offline Whisper
fallback when Gemini is unconfigured or raises.

GeminiService.__init__ constructs a real google.generativeai.GenerativeModel
when settings.gemini_api_key is set (true in tests, via conftest's dummy
key) -- that construction itself makes no network call, only
.generate_content() does, so tests construct a real GeminiService and
monkeypatch self.model.generate_content per test.
"""

from unittest.mock import MagicMock, patch

import pytest

from app.services.gemini_service import GeminiService


def _service_with_fake_model(response_text: str | None = None, side_effect=None) -> GeminiService:
    service = GeminiService()
    fake_model = MagicMock()
    if side_effect is not None:
        fake_model.generate_content.side_effect = side_effect
    else:
        fake_model.generate_content.return_value = MagicMock(text=response_text)
    service.model = fake_model
    return service


def _service_without_gemini() -> GeminiService:
    service = GeminiService()
    service.model = None
    return service


@pytest.mark.asyncio
async def test_transcribe_audio_bytes_returns_gemini_text_when_configured():
    service = _service_with_fake_model(response_text="Transcribed text.")

    result = await service.transcribe_audio_bytes(b"audio-bytes", "audio/mp4")

    assert result == "Transcribed text."


@pytest.mark.asyncio
async def test_transcribe_audio_bytes_falls_back_to_whisper_when_gemini_raises():
    service = _service_with_fake_model(side_effect=RuntimeError("quota exceeded"))

    with patch(
        "app.services.whisper_service.WhisperService.transcribe",
        return_value="Whisper transcription.",
    ) as fake_whisper:
        result = await service.transcribe_audio_bytes(b"audio-bytes", "audio/mp4")

    assert result == "Whisper transcription."
    fake_whisper.assert_called_once()


@pytest.mark.asyncio
async def test_transcribe_audio_bytes_falls_back_to_whisper_when_no_api_key():
    service = _service_without_gemini()

    with patch(
        "app.services.whisper_service.WhisperService.transcribe",
        return_value="Whisper transcription.",
    ) as fake_whisper:
        result = await service.transcribe_audio_bytes(b"audio-bytes", "audio/mp4")

    assert result == "Whisper transcription."
    fake_whisper.assert_called_once()


@pytest.mark.asyncio
async def test_transcribe_audio_bytes_writes_a_temp_file_matching_the_mime_type():
    """The Whisper fallback needs a file path, so bytes get written to a
    suffixed temp file first -- assert the suffix matches the MIME type and
    that the temp file is cleaned up afterward.
    """
    service = _service_without_gemini()
    captured_path = {}

    def fake_transcribe(path):
        captured_path["path"] = path
        assert path.endswith(".wav")
        import os

        assert os.path.exists(path)
        return "ok"

    with patch(
        "app.services.whisper_service.WhisperService.transcribe",
        side_effect=fake_transcribe,
    ):
        await service.transcribe_audio_bytes(b"audio-bytes", "audio/wav")

    import os

    assert not os.path.exists(captured_path["path"])


@pytest.mark.asyncio
async def test_rewrite_for_archaeology_raises_when_gemini_not_configured():
    service = _service_without_gemini()

    with pytest.raises(ValueError, match="not configured"):
        await service.rewrite_for_archaeology("some text")


@pytest.mark.asyncio
async def test_rewrite_for_archaeology_returns_none_for_blank_text():
    service = _service_with_fake_model(response_text="should not be used")

    result = await service.rewrite_for_archaeology("   ")

    assert result is None


@pytest.mark.asyncio
async def test_rewrite_for_archaeology_returns_gemini_text():
    service = _service_with_fake_model(response_text="Formal rewritten text.")

    result = await service.rewrite_for_archaeology("found pottery")

    assert result == "Formal rewritten text."


@pytest.mark.asyncio
async def test_rewrite_for_archaeology_returns_none_when_gemini_raises():
    service = _service_with_fake_model(side_effect=RuntimeError("boom"))

    result = await service.rewrite_for_archaeology("found pottery")

    assert result is None


@pytest.mark.asyncio
async def test_analyze_image_bytes_raises_when_gemini_not_configured():
    service = _service_without_gemini()

    with pytest.raises(ValueError, match="not configured"):
        await service.analyze_image_bytes(b"image-bytes")


@pytest.mark.asyncio
async def test_analyze_image_bytes_strips_json_code_fences():
    service = _service_with_fake_model(response_text='```json\n{"material": "ceramic"}\n```')

    result = await service.analyze_image_bytes(b"image-bytes")

    assert result == '{"material": "ceramic"}'


@pytest.mark.asyncio
async def test_analyze_image_bytes_returns_none_when_gemini_raises():
    service = _service_with_fake_model(side_effect=RuntimeError("boom"))

    result = await service.analyze_image_bytes(b"image-bytes")

    assert result is None


@pytest.mark.asyncio
async def test_extract_text_from_image_raises_when_gemini_not_configured():
    service = _service_without_gemini()

    with pytest.raises(ValueError, match="not configured"):
        await service.extract_text_from_image(b"image-bytes")


@pytest.mark.asyncio
async def test_extract_text_from_image_returns_gemini_text():
    service = _service_with_fake_model(response_text="Extracted text.")

    result = await service.extract_text_from_image(b"image-bytes")

    assert result == "Extracted text."


@pytest.mark.asyncio
async def test_extract_text_from_image_returns_none_when_gemini_raises():
    service = _service_with_fake_model(side_effect=RuntimeError("boom"))

    result = await service.extract_text_from_image(b"image-bytes")

    assert result is None
