# GitHub Codespaces Setup Guide

## ✅ What Was Fixed

### 1. Backend Configuration ✓
- **File**: `backend/main.py`
- **Change**: Server now binds to `0.0.0.0:8000` instead of `127.0.0.1:8000`
- **Why**: Allows external connections in Codespaces
- **Status**: ✅ Working - Backend accessible at `https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev`

### 2. Frontend API Configuration ✓
- **New File**: `frontend/lib/config/api_config.dart`
- **Feature**: Auto-detects environment and uses correct backend URL
- **Behavior**:
  - In Codespaces: Uses forwarded port URL (`https://CODESPACE-8000.app.github.dev`)
  - In Local Dev: Uses `http://localhost:8000`
  - In Production: Can be configured for production URLs

### 3. Enhanced Error Handling ✓
- **File**: `frontend/lib/services/community_service.dart`
- **Added**:
  - Detailed error logging with emoji markers
  - Network exception handling
  - Timeout handling (15 seconds)
  - Troubleshooting hints in error messages

### 4. Anonymous Voting ✓
- **File**: `frontend/lib/widgets/community_vote_box.dart`
- **Change**: Removed user login requirement
- **Feature**: Auto-generates anonymous user IDs (`anonymous_12345`)
- **Result**: Users can vote without authentication

## 🧪 Testing the Fix

### 1. Verify Backend is Running
```bash
curl https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev/health
# Expected output: {"status":"healthy","vertex_ai_configured":false}
```

### 2. Test Community Post Endpoint
```bash
curl -X POST "https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev/community/post" \
  -H "Content-Type: application/json" \
  -d '{"claim_text": "Test claim", "ai_verdict": "Legit"}'
# Expected: {"success":true,"claim_id":"...","message":"Claim posted..."}
```

### 3. Frontend Console Logs
When you click "Post to Community", check browser console (F12) for:
```
🌐 Detected Codespaces environment
🔗 Using backend URL: https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev/community
📤 Posting claim to: https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev/community/post
📥 Response status: 200
📥 Response body: {"success":true,...}
```

## 📝 How to Use

### Starting the Backend
```bash
cd /workspaces/Gemini3Pro-XNFork/backend
python main.py
```

### Starting the Frontend (Development)
```bash
cd /workspaces/Gemini3Pro-XNFork/frontend
flutter run -d web-server --web-port 3000
```

### Building for Web
```bash
cd /workspaces/Gemini3Pro-XNFork/frontend
flutter build web
cd build/web
python3 -m http.server 8080
```

## 🔍 Debugging Tips

### If "Failed to fetch" error persists:

1. **Check Backend is Running**
   ```bash
   ps aux | grep "python main.py"
   ```

2. **Check Port Accessibility**
   ```bash
   curl http://localhost:8000/health
   ```

3. **Check Frontend Console**
   - Open browser DevTools (F12)
   - Look for 📤 and 📥 emoji logs
   - Check the exact URL being used

4. **Check CORS**
   - Backend logs should show the request
   - CORS is already configured to allow all origins

5. **Port Forwarding in Codespaces**
   - Go to "Ports" tab in VS Code
   - Ensure port 8000 is listed and has "Public" visibility
   - If not, right-click → "Port Visibility" → "Public"

## 🌐 Environment Detection Logic

The `ApiConfig.getBaseUrl()` method automatically detects:

1. **Codespaces** (hostname contains `app.github.dev`):
   - Extracts codespace name from current URL
   - Constructs backend URL: `https://{CODESPACE}-8000.app.github.dev`

2. **Localhost**:
   - Uses `http://localhost:8000`

3. **Production** (can be extended):
   - Can add custom domain detection

## 🚀 Next Steps

1. **Hot Reload/Restart Flutter App**: The changes won't take effect until you restart
   ```bash
   # In flutter terminal, press 'r' for hot reload or 'R' for hot restart
   ```

2. **Clear Browser Cache**: Sometimes helps with web apps
   - Open DevTools → Network tab → Check "Disable cache"

3. **Test the Flow**:
   - Analyze a news article
   - Click "Ask the community to verify"
   - Fill in your verdict (Legit/Suspect/Fake)
   - Add optional notes
   - Click "Post to Community"
   - Check console logs for success

## 📊 Expected Console Output

```
🌐 Detected Codespaces environment
🔗 Using backend URL: https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev/community
📤 Posting claim to: https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev/community/post
   Claim: The Earth is flat...
   Verdict: Fake
📥 Response status: 200
📥 Response body: {"success":true,"claim_id":"1408dfcb152640f6","message":"Claim posted to community successfully"}
📤 Submitting vote to: https://obscure-umbrella-x59rgpv44rwgfxvp-8000.app.github.dev/community/vote
   Claim ID: 1408dfcb152640f6
   User ID: anonymous_45678
   Verdict: FAKE
📥 Vote response status: 200
📥 Vote response body: {"success":true,"trust_score":0.0,"vote_count":1,"message":"Vote submitted successfully"}
```

## ❌ Common Errors & Solutions

### ClientException: Failed to fetch
**Cause**: Backend not accessible from frontend
**Solutions**:
1. Restart backend: `python main.py`
2. Check port 8000 is public in Codespaces
3. Verify URL in console logs

### TimeoutException
**Cause**: Backend is slow or unresponsive
**Solutions**:
1. Check backend logs for errors
2. Increase timeout in `community_service.dart` (currently 15s)

### CORS Error
**Cause**: Cross-origin request blocked
**Solutions**:
1. Backend already has CORS enabled for all origins
2. Check backend logs to see if request is reaching it
3. Verify backend is running on correct port

## 🎉 Success Indicators

✅ Backend shows: `INFO: 127.0.0.1:51198 - "POST /community/post HTTP/1.1" 200 OK`
✅ Frontend console shows: `📥 Response status: 200`
✅ UI shows: "Vote posted to community." green snackbar
✅ Redirects to Community Screen
