# VeriScan: Antigravity Update 🚀

VeriScan is a multimodal fact-checking dashboard powered by Google's Gemini 2.0 Flash model with Google Search Grounding. It analyzes text, URLs, and images to provide forensic verdicts on potential misinformation.

## Technology Stack

- **AI Engine:** GCP Vertex AI (Gemini 2.0 Flash) for multimodal processing of text, images, and links.
- **Backend:** Python & FastAPI acting as a high-performance orchestrator for AI inference.
- **Frontend:** Flutter for a consistent, high-performance UI across Web and Mobile deployments.
- **Database & Hosting:** Firebase (Firestore & Hosting) for scalable data storage, user history, and rapid deployment.

## 💡 Innovation & Unique Selling Point (USP)

- **Direct-Share Listener:** VeriScan features a system-level integration allowing users to share media directly from apps like WhatsApp, Instagram, and Facebook via native "Share Sheets".
- **Multimodal Reasoning:** Unlike traditional tools, VeriScan uses Vertex AI to perform cross-modal analysis, checking if an image's visual context contradicts the claims in the associated text.
- **Human-in-the-Loop:** A unique Community Vote feature allows everyday users to verify AI verdicts, adding cultural nuance and building collective trust.
- **Explainable Grounding:** Every verdict includes a forensic breakdown of logical fallacies and evidence cards linked to real-world sources via Google Search Grounding.

## Features
- **Multimodal Input**: Text, URL, and Image analysis.
- **Forensic Analysis**: Breakdown of logical fallacies and tone.
- **Google Search Grounding**: Evidence cards linked to real-world sources.
- **Bento Grid Dashboard**: A "Obsidian & Gilded" themed high-performance UI.

## Challenges Faced
- **Multi-Platform Integration**: We encountered significant "Java version" configurations and library compatibility issues where certain Dart packages worked on Web but failed on Mobile. We resolved this by auditing our dependencies and switching to strictly cross-platform compatible libraries.
- **CORS & API Connectivity**: During the implementation of the Community Vote feature, we faced ClientException: Failed to fetch errors due to Cross-Origin Resource Sharing (CORS) restrictions. We implemented custom CORS middleware in FastAPI and refactored the frontend to dynamically generate backend URLs based on the environment.
- **Accuracy vs. Latency Trade-off**: Balancing the deep-search capabilities of Google Search Grounding with user expectations for speed was a hurdle. We prioritized accuracy, deciding that a slightly longer wait for a verified, evidence-backed verdict was more valuable than a near-instant but ungrounded response.

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
