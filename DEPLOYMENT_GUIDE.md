# VeriScan Deployment Guide

This guide is for teammates who want to run and deploy their own instance of VeriScan. **Crucially, you should deploy to your own Firebase project to prevent over-billing on the main account.**

## 1. Prerequisites

Ensure you have the following installed:
- **Python 3.10+**
- **Flutter SDK**
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Git**

## 2. Configuration (IMPORTANT)

Before running or deploying, you must configure the project to use **your** infrastructure.

### A. Backend Credentials
1.  Create a project in [Google Cloud Console](https://console.cloud.google.com/).
2.  Enable **Vertex AI API**.
3.  Create a Service Account with "Vertex AI User" role.
4.  Download the JSON key.
5.  Rename it to `service-account.json`.
6.  Place it in the `backend/` directory.

### B. Firebase Project
#### CRITICAL WARNINGS (READ FIRST)
**The "Existing Project" Rule:**
- When you run firebase init, the CLI will ask if you want to Create a New Project or Use an Existing Project. ALWAYS choose "Use an Existing Project" and select our team project from the list.
- Why? Creating a new one creates a separate, empty environment that won't sync with the rest of the team.

**The Blaze Plan & Free Credits: Our project is on the Blaze Plan.**
- Don't worry about the "Pay-as-you-go" label. We are using the Google Cloud $300 Free Trial credits.
- The Blaze plan is required to use features like Cloud Functions, but as long as we stay within the "Always Free" usage limits (which are quite generous), it will deduct from the $0 credits first. You won't be charged personally.

**Steps:**
1.  Create a project in [Firebase Console](https://console.firebase.google.com/).
2.  Upgrade to **Blaze Plan** (Pay-as-you-go) - Required for Cloud Functions.
3.  In your terminal, navigate to the project root:
    ```bash
    firebase login
    firebase use --add <YOUR_PROJECT_ID>
    ```

### C. Frontend API URL
1.  Open `frontend/lib/services/fact_check_service.dart`.
2.  Locate the `baseUrl` definition.
3.  **Update the production URL** to match *your* Cloud Function URL (you will get this after your first deploy, or you can construct it: `https://us-central1-<YOUR_PROJECT_ID>.cloudfunctions.net/analyze`).

```dart
final String baseUrl = kReleaseMode
    ? 'https://us-central1-<YOUR_PROJECT_ID>.cloudfunctions.net/analyze' // <--- UPDATE THIS
    : 'http://127.0.0.1:8000';
```

---

## 3. Local Development (Testing)

Run the backend and frontend locally to test changes without deploying. The app is configured to verify `kReleaseMode` and switch to `localhost` automatically.

### Step 1: Run Backend
Open a terminal in the `backend/` directory:
```bash
# Install dependencies (first time only)
pip install -r requirements.txt

# Run server (runs on port 8080)
python main.py
```

### Step 2: Run Frontend
Open a new terminal in the `frontend/` directory:
```bash
# Run in Chrome
flutter run -d chrome
```

**How it works:**
- When running locally (debug mode), `kReleaseMode` is `false`.
- The app sends requests to `http://127.0.0.1:8080`.
- This incurs **Vertex AI costs** on your Google Cloud project (via `service-account.json`) but **no Firebase Hosting/Function costs**.

---

## 4. Production Deployment

When you are ready to publish, build the app and deploy it to Firebase.

### Step 1: Build Frontend
This compiles the Dart code into optimized JavaScript for the web.
```bash
cd frontend
flutter build web --release
```
*Note: This sets `kReleaseMode` to `true`, ensuring the app uses your production Cloud Function URL.*

### Step 2: Deploy to Firebase
This uploads your web assets (Hosting) and your backend code (Functions).
```bash
# From the project root
firebase deploy
```

### Step 3: Verify
- The command will output your **Hosting URL** (e.g., https://<YOUR-PROJECT>.web.app).
- Visit the URL and test the analyzer.
- Since `kReleaseMode` is `true`, it will send requests to your deployed Cloud Function.

---

## Summary Checklist

| Action | Command | URL Used |
| :--- | :--- | :--- |
| **Local Backend** | `python main.py` | `localhost:8080` (Server) |
| **Local Frontend** | `flutter run -d chrome` | `http://127.0.0.1:8080` |
| **Build Web** | `flutter build web --release` | `https://<YOUR-PROJECT>.cloudfunctions.net/analyze` |
| **Deploy** | `firebase deploy` | N/A |
