import asyncio
import sys
import os

# Ensure backend directory is in python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import engine
from sqlalchemy import text

async def check_tables():
    print("🔌 Connecting to database...")
    try:
        async with engine.begin() as conn:
            print("✅ Connected.")
            
            # Check for pgvector extension
            print("🔍 Checking extensions...")
            res = await conn.execute(text("SELECT extname FROM pg_extension"))
            extensions = [row[0] for row in res.fetchall()]
            if 'vector' in extensions:
                print("✅ 'vector' extension is installed.")
            else:
                print("❌ 'vector' extension is NOT installed.")
                print("🛠 Attempting to create extension 'vector'...")
                try:
                    await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
                    print("✅ Successfully enabled 'vector' extension.")
                    await conn.commit() # Commit the extension creation immediately
                except Exception as ext_e:
                    print(f"❌ Failed to create extension: {ext_e}")
                    print("   NOTE: You might need to install pgvector on your OS. (e.g. 'brew install pgvector')")

            # Check tables
            print("🔍 Checking tables...")
            result = await conn.execute(text(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
            ))
            tables = [row[0] for row in result.fetchall()]
            print(f"📊 Tables found: {tables}")
            
            # Check for specific vector tables
            target_tables = ["data_diary_embeddings", "diary_embeddings"]
            found = False
            for t in target_tables:
                if t in tables:
                    found = True
                    print(f"✅ Found vector table: '{t}'")
                    # Check count
                    count_res = await conn.execute(text(f"SELECT count(*) FROM {t}"))
                    count = count_res.scalar()
                    print(f"   Rows: {count}")
            
            if not found:
                print("❌ No vector table found (expected 'data_diary_embeddings' or 'diary_embeddings').")
                
    except Exception as e:
        print(f"❌ Error connecting to DB: {e}")

if __name__ == "__main__":
    asyncio.run(check_tables())
