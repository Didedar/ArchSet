
import os
import whisper
import warnings
from functools import lru_cache
from typing import Optional

# Filter annoying whisper warnings
warnings.filterwarnings("ignore", category=UserWarning)

class WhisperService:
    """Service for offline speech-to-text using OpenAI Whisper."""
    
    _model = None
    
    @classmethod
    def get_model(cls):
        """Lazy load the Whisper model."""
        if cls._model is None:
            print("Loading Whisper 'base' model for offline transcription...")
            # 'base' is a good balance for offline mobile/desktop app
            cls._model = whisper.load_model("base")
            print("Whisper model loaded successfully.")
        return cls._model

    @classmethod
    def ensure_model_downloaded(cls):
        """
        Triggers the model download if not already present.
        Call this during app startup depending on strategy.
        """
        try:
            print("Checking Whisper model availability...")
            cls.get_model()  # This triggers download if needed
        except Exception as e:
            print(f"Warning: Could not load/download Whisper model: {e}")

    @classmethod
    def transcribe(cls, audio_path: str) -> Optional[str]:
        """
        Transcribe audio file using local Whisper model.
        
        Args:
            audio_path: Path to the audio file
            
        Returns:
            Transcribed text or None if error
        """
        try:
            model = cls.get_model()
            result = model.transcribe(audio_path)
            return result["text"].strip()
        except Exception as e:
            print(f"Whisper transcription error: {e}")
            return None

# Global instance pattern not strictly needed as using @classmethod, 
# but consistent with other services if we want to instantiate.
whisper_service = WhisperService()
