"""
Gemini AI service for audio transcription and text rewriting.
"""

import os
from pathlib import Path
from typing import Optional
import google.generativeai as genai

from ..config import get_settings

settings = get_settings()


class GeminiService:
    """Service for Gemini AI operations."""
    
    def __init__(self):
        """Initialize Gemini client."""
        if settings.gemini_api_key:
            genai.configure(api_key=settings.gemini_api_key)
            self.model = genai.GenerativeModel('gemini-3-flash-preview')
        else:
            self.model = None
    
    async def transcribe_audio(self, audio_path: str) -> Optional[str]:
        """
        Transcribe audio file to text.
        
        Args:
            audio_path: Path to the audio file
            
        Returns:
            Transcribed text or None if error
        """
        # Try Gemini first (online)
        if self.model:
            try:
                # Check if file exists
                if not os.path.exists(audio_path):
                    raise FileNotFoundError(f"Audio file not found: {audio_path}")
                
                # Read audio file
                with open(audio_path, "rb") as f:
                    audio_bytes = f.read()
                
                # Determine MIME type based on extension
                extension = Path(audio_path).suffix.lower()
                mime_types = {
                    ".m4a": "audio/mp4",
                    ".mp3": "audio/mpeg",
                    ".wav": "audio/wav",
                    ".webm": "audio/webm",
                    ".ogg": "audio/ogg",
                }
                mime_type = mime_types.get(extension, "audio/mpeg")
                
                # Create content for Gemini
                response = self.model.generate_content([
                    "Transcribe the following audio file verbatim. Do not add any conversational filler.",
                    {
                        "mime_type": mime_type,
                        "data": audio_bytes
                    }
                ])
                
                return response.text
                
            except Exception as e:
                print(f"Gemini transcription error: {e}. Switching to offline Whisper transcription.")
        else:
            print("Gemini API key not configured. Using offline Whisper transcription.")

        # Fallback to Whisper (offline)
        from .whisper_service import WhisperService
        return WhisperService.transcribe(audio_path)
    
    async def transcribe_audio_bytes(
        self,
        audio_bytes: bytes,
        mime_type: str = "audio/mp4"
    ) -> Optional[str]:
        """
        Transcribe audio bytes to text.
        
        Args:
            audio_bytes: Audio data as bytes
            mime_type: MIME type of the audio
            
        Returns:
            Transcribed text or None if error
        """
        # Try Gemini first (online)
        if self.model:
            try:
                response = self.model.generate_content([
                    "Transcribe the following audio file verbatim. Do not add any conversational filler.",
                    {
                        "mime_type": mime_type,
                        "data": audio_bytes
                    }
                ])
                
                return response.text
                
            except Exception as e:
                print(f"Gemini transcription error: {e}. Switching to offline Whisper transcription.")
        else:
            print("Gemini API key not configured. Using offline Whisper transcription.")

        # Fallback to Whisper (offline)
        # Whisper requires a file path, so write bytes to temp file
        import tempfile
        from .whisper_service import WhisperService
        
        suffix = ".mp3" # Default or derive from mime_type if critical
        if "wav" in mime_type: suffix = ".wav"
        elif "m4a" in mime_type or "mp4" in mime_type: suffix = ".m4a"
        elif "ogg" in mime_type: suffix = ".ogg"

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_file.write(audio_bytes)
            temp_path = temp_file.name
        
        try:
            return WhisperService.transcribe(temp_path)
        finally:
            if os.path.exists(temp_path):
                os.unlink(temp_path)
    
    async def rewrite_for_archaeology(self, text: str) -> Optional[str]:
        """
        Rewrite text according to archaeological field documentation standards.
        
        Args:
            text: Original text to rewrite
            
        Returns:
            Rewritten text or None if error
        """
        if not self.model:
            raise ValueError("Gemini API key not configured")
        
        if not text.strip():
            return None
        
        try:
            prompt = """You are an expert archaeological documentation specialist. Rewrite the following text according to professional archaeological field documentation standards.

Follow these guidelines:
1. First, detect the language of the provided {text}. 
2. You must provide the entire response (the rewritten documentation and any headings) in the same language as the input text.
3. Use formal, objective, and precise language
4. Include proper stratigraphic terminology where applicable
5. Use correct archaeological nomenclature for artifacts, features, and contexts
6. Structure the text with clear sections if needed (e.g., Context, Description, Finds, Interpretation)
7. Maintain scientific accuracy and avoid speculation
8. Use passive voice where appropriate for objectivity
9. Include measurement units in metric system
10. Reference spatial relationships clearly (e.g., north, south, above, below)
11. Preserve all factual information from the original text
12. Format dates in archaeological standard format if mentioned

Original text:
{text}

Please provide the rewritten documentation:"""
            
            response = self.model.generate_content(prompt.format(text=text))
            return response.text
            
        except Exception as e:
            print(f"Gemini rewrite error: {e}")
            return None

    async def analyze_image_bytes(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        latitude: Optional[float] = None,
        longitude: Optional[float] = None
    ) -> Optional[str]:
        """
        Analyze an image to extract archaeological context.
        
        Args:
            image_bytes: Image data as bytes
            mime_type: MIME type of the image
            latitude: Optional latitude where photo was taken
            longitude: Optional longitude where photo was taken
            
        Returns:
            JSON string containing the analysis
        """
        if not self.model:
            raise ValueError("Gemini API key not configured")
        
        try:
            location_info = ""
            if latitude is not None and longitude is not None:
                location_info = f"\n            Note: The photo was taken at coordinates: Latitude {latitude}, Longitude {longitude}. Use this to infer location context if possible."

            prompt = f"""
            Analyze this archaeological photo and provide the following information in JSON format.
            This is what distinguishes science from treasure hunting.{location_info}.
            First, write information in russian. You must provide the entire response
            
            1. Spatial Context (Where?)
            - Stratigraphic Index (Layer/Unit): The number of the earth's layer (e.g., "US 105"). If unknown, state "unknown".
            - Square/Excavation Site: (E.g., "Sector B, Square 4").
            - Coordinates (X, Y): Estimate if possible from markers, otherwise "unknown".
            - Leveling (Z - Depth): Depth from the "zero point".
            - Position Status: "In situ", "In a redeposited layer", or "In a spoil heap".
            
            2. Physical Characteristics (What?)
            - Material: (Ceramics, Bone, Bronze, Iron, Glass, Stone, etc).
            - Object Type: (Vessel Wall Fragment, Rim, Handle, Arrowhead, Coin, etc).
            - Dimensions: Estimate Length, Width, Thickness, Diameter if markers are present.
            - Color: Describe appropriately (Munsell scale reference if possible).
            - Preservation: (Whole, Fragmented, Corroded, Fire Traces).
            
            3. Relational Context (What is it related to?)
            - Connection to structures: e.g., "Found inside Hearth #2".
            - Connection to other objects: e.g., "Found next to Skeleton #1".
            - Collection: Does this belong to a known collection/group?
            
            4. Administrative data (Who and When?)
            - Unique code (ID): Suggest a format like Year-Excavation-Sector-Number if visible, otherwise "unknown".
            - Finder: "unknown" (unless written).
            - Discovery date and time: "unknown" (unless written).
            
            Output ONLY valid JSON matching this structure:
            {{
                "spatial_context": {{
                    "stratigraphic_index": "string",
                    "square_site": "string",
                    "coordinates": "string",
                    "leveling": "string",
                    "position_status": "string"
                }},
                "physical_characteristics": {{
                    "material": "string",
                    "object_type": "string",
                    "dimensions": "string",
                    "color": "string",
                    "preservation": "string"
                }},
                "relational_context": {{
                    "connection_structures": "string",
                    "connection_objects": "string",
                    "collection": "string"
                }},
                "administrative_data": {{
                    "unique_code": "string",
                    "finder": "string",
                    "discovery_date": "string"
                }}
            }}
            """
            
            response = self.model.generate_content([
                prompt,
                {
                    "mime_type": mime_type,
                    "data": image_bytes
                }
            ])
            
            # Extract JSON from response if it's wrapped in code blocks
            text = response.text
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0].strip()
            elif "```" in text:
                text = text.split("```")[1].split("```")[0].strip()
                
            return text
            
        except Exception as e:
            print(f"Gemini image analysis error: {e}")
            return None

    async def extract_text_from_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg"
    ) -> Optional[str]:
        """
        Extract text from an image (OCR).
        
        Args:
            image_bytes: Image data as bytes
            mime_type: MIME type of the image
            
        Returns:
            Extracted text or None if error
        """
        if not self.model:
            raise ValueError("Gemini API key not configured")
            
        try:
            prompt = "Extract all text visible in this image. Provide ONLY the extracted text, maintaining the original layout as much as possible."
            
            response = self.model.generate_content([
                prompt,
                {
                    "mime_type": mime_type,
                    "data": image_bytes
                }
            ])
            
            return response.text
            
        except Exception as e:
            print(f"Gemini OCR error: {e}")
            return None


# Singleton instance
_gemini_service: Optional[GeminiService] = None


def get_gemini_service() -> GeminiService:
    """Get or create GeminiService instance."""
    global _gemini_service
    if _gemini_service is None:
        _gemini_service = GeminiService()
    return _gemini_service
