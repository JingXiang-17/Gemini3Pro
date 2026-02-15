# Run instructions

## Backend (Python / FastAPI)
- Open a terminal in `backend`.
- Copy `.env.example` to `.env` and set `SERVICE_ACCOUNT_PATH` or `GEMINI_API_KEY` if you have them.
- Run the helper script on Windows:

```bat
cd backend
run_backend.bat
```

Or, manually:

```bat
cd backend
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Health: http://localhost:8000/health

## Flutter frontend
- Open the `frontend` directory in your Flutter-capable environment (VS Code, Android Studio).
- If testing on Android emulator, update the backend base URL in `frontend/lib/services/api_service.dart` to `http://10.0.2.2:8000`.
- Run:

```bash
cd frontend
flutter pub get
flutter run
```

Notes:
- The backend will use a lightweight heuristic fallback if Vertex AI credentials or SDK are not configured — this allows the app to function for development without GCP access.
