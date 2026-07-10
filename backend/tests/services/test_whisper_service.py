"""Unit tests for WhisperService. whisper.load_model("base") downloads and
loads a real ML model, so every test here mocks it out -- these tests must
never let a real model load happen.

_model is a class-level cache (shared across the whole process), so it's
reset before and after every test to keep tests isolated from each other.
"""

from unittest.mock import MagicMock, patch

import pytest

from app.services.whisper_service import WhisperService


@pytest.fixture(autouse=True)
def _reset_model_cache():
    WhisperService._model = None
    yield
    WhisperService._model = None


def test_get_model_loads_and_caches_the_model():
    fake_model = MagicMock()
    with patch("whisper.load_model", return_value=fake_model) as fake_load:
        first = WhisperService.get_model()
        second = WhisperService.get_model()

    fake_load.assert_called_once_with("base")
    assert first is fake_model
    assert second is fake_model


def test_transcribe_returns_the_stripped_text():
    fake_model = MagicMock()
    fake_model.transcribe.return_value = {"text": "  found pottery shards  "}

    with patch("whisper.load_model", return_value=fake_model):
        result = WhisperService.transcribe("/fake/path.wav")

    assert result == "found pottery shards"
    fake_model.transcribe.assert_called_once_with("/fake/path.wav")


def test_transcribe_returns_none_on_failure():
    fake_model = MagicMock()
    fake_model.transcribe.side_effect = RuntimeError("corrupt audio file")

    with patch("whisper.load_model", return_value=fake_model):
        result = WhisperService.transcribe("/fake/path.wav")

    assert result is None


def test_ensure_model_downloaded_swallows_errors():
    with patch("whisper.load_model", side_effect=RuntimeError("no network")):
        # Must not raise -- this runs at app startup and a model-load
        # failure shouldn't take the whole app down.
        WhisperService.ensure_model_downloaded()


def test_ensure_model_downloaded_triggers_a_load():
    fake_model = MagicMock()
    with patch("whisper.load_model", return_value=fake_model) as fake_load:
        WhisperService.ensure_model_downloaded()

    fake_load.assert_called_once_with("base")
