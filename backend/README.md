# ArchSet Backend

Python FastAPI backend for the ArchSet archaeological diary mobile application.

## Features

- 🔐 **JWT Authentication** - Secure user registration and login
- 📝 **Notes API** - Full CRUD operations for diary entries
- 📁 **Folders API** - Organize notes into folders
- 🔄 **Sync API** - Offline-first data synchronization
- 🤖 **Gemini AI** - Audio transcription and archaeological text rewriting

## Quick Start

### 1. Create Virtual Environment

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your settings (especially GEMINI_API_KEY)
```

### 4. Run the Server

```bash
# Development mode with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or using Python directly
python -m app.main
```

### 5. Access API Documentation

Open http://localhost:8000/docs for interactive Swagger UI documentation.

## API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login and get tokens |
| POST | `/api/v1/auth/refresh` | Refresh access token |
| GET | `/api/v1/auth/me` | Get current user |

### Notes

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/notes` | List all notes |
| POST | `/api/v1/notes` | Create note |
| GET | `/api/v1/notes/{id}` | Get note |
| PUT | `/api/v1/notes/{id}` | Update note |
| DELETE | `/api/v1/notes/{id}` | Delete note |

### Folders

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/folders` | List all folders |
| POST | `/api/v1/folders` | Create folder |
| PUT | `/api/v1/folders/{id}` | Update folder |
| DELETE | `/api/v1/folders/{id}` | Delete folder |

### Sync

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/sync` | Sync local data |

### Gemini AI

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/gemini/transcribe` | Transcribe audio |
| POST | `/api/v1/gemini/rewrite` | Rewrite for archaeology |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Server host | `0.0.0.0` |
| `PORT` | Server port | `8000` |
| `DEBUG` | Enable debug mode | `false` |
| `DATABASE_URL` | Database connection | SQLite |
| `SECRET_KEY` | JWT secret key | - |
| `GEMINI_API_KEY` | Google Gemini API key | - |

## Project Structure

```
backend/
├── app/
│   ├── main.py           # FastAPI application
│   ├── config.py         # Settings
│   ├── database.py       # SQLAlchemy setup
│   ├── models/           # Database models
│   ├── schemas/          # Pydantic schemas
│   ├── routers/          # API endpoints
│   ├── services/         # Business logic
│   └── utils/            # Utilities
├── requirements.txt
├── .env.example
└── README.md
```
