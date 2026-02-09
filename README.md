# VeriScan: Antigravity Update 🚀

VeriScan is a multimodal fact-checking dashboard powered by Google's Gemini 2.5 Flash-Lite model with Google Search Grounding. It analyzes text, URLs, and images to provide forensic verdicts on potential misinformation.

## features
- **Multimodal Input**: Text, URL, and Image analysis.
- **Forensic Analysis**: Breakdown of logical fallacies and tone.
- **Google Search Grounding**: Evidence cards linked to real-world sources.
- **Bento Grid Dashboard**: A "Obsidian & Gilded" themed high-performance UI.

---

## 🛠️ Setup Instructions

### Prerequisites
- **Python 3.10+**
- **Flutter SDK** (Latest Stable)
- **Google Cloud Service Account** (`service-account.json`) with Vertex AI permissions.

### 1. Backend Setup
Navigate to the `backend` directory:
```bash
cd backend
```

Install dependencies:
```bash
pip install -r requirements.txt
```

**Important**: Ensure your `service-account.json` key is placed in the `backend/` directory.

Run the server:
```bash
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*The API will be available at `http://localhost:8000`.*

### 2. Frontend Setup
Navigate to the `frontend` directory:
```bash
cd frontend
```

Get dependencies:
```bash
flutter pub get
```

Run the app (Chrome recommended for dev):
```bash
flutter run -d chrome
```

---

## ⚠️ Troubleshooting
- **Backend 400 Errors**: Ensure you have valid credentials in `service-account.json`.
- **Image Upload Failures**: The app supports `.jpg`, `.jpeg`, and `.png`.

---

**Built with 🖤 by the VeriScan Team**
