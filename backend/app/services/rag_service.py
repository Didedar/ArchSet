"""
RAG Service using LlamaIndex and PostgreSQL (pgvector).
"""

import logging
from typing import List, Optional
from llama_index.core import (
    VectorStoreIndex,
    StorageContext,
    Document,
    Settings as LlamaSettings,
)
from llama_index.vector_stores.postgres import PGVectorStore
from llama_index.llms.gemini import Gemini
from llama_index.embeddings.gemini import GeminiEmbedding
from ..config import get_settings

# Setup logging
logger = logging.getLogger(__name__)
settings = get_settings()

# Initialize LlamaIndex Settings globally
# Initialize LlamaIndex Settings globally
if settings.gemini_api_key:
    try:
        logger.info("Initializing LlamaIndex with Gemini...")
        # LLM
        LlamaSettings.llm = Gemini(
            api_key=settings.gemini_api_key,
            model_name="models/gemini-3-flash-preview"
        )
        # Embedding
        LlamaSettings.embed_model = GeminiEmbedding(
            api_key=settings.gemini_api_key,
            model_name="models/gemini-embedding-001"
        )
        logger.info("LlamaIndex Settings initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize LlamaIndex settings: {e}")
        raise
else:
    logger.error("GEMINI_API_KEY not found in settings! LlamaIndex will default to OpenAI (causing errors).")
    # We must raise here because otherwise LlamaIndex defaults to OpenAI and fails later
    raise ValueError("GEMINI_API_KEY is not set. Please set it in your .env file.")


class RAGService:
    def __init__(self):
        self.storage_path = "./storage" # Local directory for vector store
        self.embed_dim = 3072

    def _get_index(self) -> VectorStoreIndex:
        """Load index from storage or create a new one."""
        import os
        from llama_index.core import load_index_from_storage
        
        if os.path.exists(self.storage_path) and os.path.exists(f"{self.storage_path}/docstore.json"):
            try:
                storage_context = StorageContext.from_defaults(persist_dir=self.storage_path)
                return load_index_from_storage(storage_context, embed_model=LlamaSettings.embed_model)
            except Exception as e:
                logger.error(f"Failed to load index from storage: {e}. Creating new one.")
                return self._create_new_index()
        else:
            return self._create_new_index()

    def _create_new_index(self) -> VectorStoreIndex:
        """Create a fresh index."""
        return VectorStoreIndex.from_documents(
            [], 
            embed_model=LlamaSettings.embed_model
        )

    async def initialize(self):
        """Initialize the vector store (ensure storage directory exists)."""
        import os
        try:
            logger.info("Initializing RAG Service (File-based)...")
            if not os.path.exists(self.storage_path):
                os.makedirs(self.storage_path)
                logger.info(f"Created storage directory at {self.storage_path}")
                
                # Initialize empty index to create files
                index = self._create_new_index()
                index.storage_context.persist(persist_dir=self.storage_path)
                logger.info("Initialized empty vector store.")
            else:
                logger.info("Existing storage found.")
                
        except Exception as e:
            logger.error(f"Failed to initialize RAG Service: {e}")

    async def sync_diary_to_vector_db(self, note_id: str, text: str, user_id: str, title: str = ""):
        """
        Ingest a diary entry into the vector store.
        """
        try:
            # Load existing index
            index = self._get_index()
            
            # Create a document
            doc = Document(
                text=text,
                metadata={
                    "note_id": note_id,
                    "user_id": user_id,
                    "title": title
                },
                excluded_llm_metadata_keys=["note_id", "user_id"],
                excluded_embed_metadata_keys=["note_id", "user_id"]
            )
            
            # Insert document
            # Note: SimpleVectorStore just appends. Duplicates might happen if we don't handle them.
            # Ideally we check if doc exists effectively. 
            # For this simple version, we just insert. 
            # (Refinement: Delete old doc with same note_id if possible, but SimpleVectorStore is basic)
            
            index.insert(doc)
            
            # Persist changes to disk
            index.storage_context.persist(persist_dir=self.storage_path)
            
            logger.info(f"Successfully synced note {note_id} to vector DB.")
            
        except Exception as e:
            logger.error(f"Error syncing diary to vector DB: {e}")
            raise

    async def chat_with_diary(self, user_query: str, chat_history: List[dict], user_id: str) -> str:
        """
        Chat with the diary context.
        """
        try:
            index = self._get_index()
            
            # Configure retriever with filters
            from llama_index.core.vector_stores import MetadataFilter, MetadataFilters
            
            # SimpleVectorStore supports metadata filters in recent LlamaIndex versions
            filters = MetadataFilters(
                filters=[
                    MetadataFilter(key="user_id", value=user_id),
                ]
            )

            # Check if index is empty
            # If docstore is empty, we can't answer questions.
            if not index.docstore.docs:
                return "I don't have any diary entries indexed yet. Please write some notes first!"
            
            chat_engine = index.as_chat_engine(
                chat_mode="context",
                filters=filters,
                llm=LlamaSettings.llm,
                system_prompt=(
                    "You are a helpful and empathetic AI assistant for an archaeology field diary app called ArchSet. "
                    "You have access to the user's personal diary entries. "
                    "Answer questions based ONLY on the provided context from their diary. "
                    "If the answer is not in the diary, say you don't know based on the diary. "
                    "Be professional but friendly."
                )
            )
            
            # Convert history
            from llama_index.core.llms import ChatMessage, MessageRole
            
            llama_history = []
            for msg in chat_history:
                role = MessageRole.USER if msg.get("role") == "user" else MessageRole.ASSISTANT
                llama_history.append(ChatMessage(role=role, content=msg.get("content", "")))
            
            response = chat_engine.chat(user_query, chat_history=llama_history)
            
            return str(response)
            
        except Exception as e:
            logger.error(f"Error chatting with diary: {e}", exc_info=True)
            return f"I'm sorry, I encountered an error while accessing your diary: {str(e)}"

# Singleton instance
rag_service = RAGService()
