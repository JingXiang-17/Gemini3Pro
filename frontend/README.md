# Fake News Detector Flutter App

A beautiful Flutter mobile application for detecting fake news using Gemini AI.

## Features

- Clean, modern Material Design 3 UI
- Real-time news analysis with Gemini AI
- Clear verdict display (Real/Fake)
- Confidence score indicator
- Detailed analysis breakdown
- Key findings highlights
- Cross-platform support (iOS, Android, Web)

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- A running instance of the backend API

## Setup

1. **Install Flutter dependencies**:
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Configure Backend URL**:
   - Open `lib/services/api_service.dart`
   - Update the `baseUrl` constant:
     - For Android emulator: `http://10.0.2.2:8000`
     - For iOS simulator: `http://localhost:8000`
     - For physical device: `http://YOUR_COMPUTER_IP:8000`

3. **Run the app**:
   ```bash
   # Make sure backend is running first!
   flutter run
   ```

## Building for Production

### Android
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
# Output will be at: build/web/
```

## Usage

1. Launch the app
2. Enter or paste a news article in the text field
3. Tap "Analyze" to check the article
4. View the results:
   - Verdict (Real/Fake)
   - Confidence score
   - Detailed analysis
   - Key findings
5. Tap "Clear" to analyze another article

## Project Structure

```
frontend/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/
│   │   └── news_analysis.dart # Data model
│   ├── screens/
│   │   └── home_screen.dart   # Main UI screen
│   └── services/
│       └── api_service.dart   # Backend API client
└── pubspec.yaml               # Dependencies
```

## Dependencies

- `http`: HTTP client for API calls
- `flutter`: Flutter framework

## Troubleshooting

### Connection Issues

If you get "Error connecting to server":
1. Ensure the backend server is running (check http://localhost:8000/health)
2. Verify the `baseUrl` in `api_service.dart` is correct for your device
3. Check firewall settings

### Build Issues

If you encounter build errors:
1. Run `flutter clean`
2. Run `flutter pub get`
3. Try running again

## Screenshots

The app features:
- Clean input interface for news articles
- Real-time loading indicator during analysis
- Color-coded results (green for real, red for fake)
- Percentage-based confidence score
- Detailed analysis text
- Bullet-pointed key findings
