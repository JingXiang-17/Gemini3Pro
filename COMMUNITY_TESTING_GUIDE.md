# Community Voting Feature - Testing Guide

## Backend Testing

### Prerequisites
```bash
cd backend
pip install -r requirements.txt
```

### Run Unit Tests
```bash
python3 test_community.py
```

Expected output:
```
============================================================
Testing Community Voting Feature
============================================================
✅ Database initialized
✅ Claim posted
✅ Claim retrieved
✅ Votes submitted
✅ Trust Score calculated
✅ User Reputation calculated
✅ All tests passed! ✅
============================================================
```

### Start Backend Server
```bash
cd backend
python3 main.py
```

The server will start on `http://localhost:8000`

### Test API Endpoints

#### 1. Post a Claim
```bash
curl -X POST http://localhost:8000/community/post \
  -H "Content-Type: application/json" \
  -d '{"claim_text": "Test claim", "ai_verdict": "REAL"}'
```

#### 2. Get Claim Data
```bash
curl -X POST http://localhost:8000/community/claim \
  -H "Content-Type: application/json" \
  -d '{"claim_text": "Test claim"}'
```

#### 3. Submit Vote
```bash
curl -X POST http://localhost:8000/community/vote \
  -H "Content-Type: application/json" \
  -d '{"claim_id": "CLAIM_ID", "user_id": "user1", "vote": true}'
```

#### 4. Get Top Claims
```bash
curl http://localhost:8000/community/top?limit=5
```

#### 5. Search Claims
```bash
curl -X POST http://localhost:8000/community/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'
```

#### 6. Get User Reputation
```bash
curl http://localhost:8000/community/reputation/user1
```

## Frontend Testing

### Prerequisites
```bash
cd frontend
flutter pub get
```

### Update API URL
Edit `frontend/lib/services/community_service.dart`:
```dart
static const String baseUrl = 'http://localhost:8000/community';
```

For deployment, change to your production URL.

### Run Frontend
```bash
cd frontend
flutter run -d chrome  # For web
flutter run -d macos   # For macOS
flutter run -d linux   # For Linux
```

## Feature Walkthrough

### 1. Sidebar Navigation
- Click the **Groups icon** (👥) in the left sidebar
- This navigates to the Community page

### 2. Community Vote Box (Results Page)
After running a fact-check:

**New Claim (Status A):**
- Shows "No human data yet"
- Displays "Post to Community" button
- Click to add claim to community database

**Existing Claim (Status B):**
- Shows Community Trust Meter with percentage
- Displays vote count
- Shows "Support this Verdict" button
- Click to submit your vote

### 3. Community Page
**Default View:**
- Displays "Top 5 Most Voted Claims"
- Each card shows:
  - Trust score percentage
  - TRUE/FALSE label
  - Claim text (truncated)
  - Vote count
  - "View Discussion" button

**Search:**
- Enter text in search bar
- Press Enter to search
- Shows matching claims
- If no results: "Not Found" state with "Go to Main Upload" button

## Mathematical Formulas

### User Reputation
```
R_u = (accurate_votes / total_votes) × log(total_votes + 1)
```

**Example:**
- User has 10 votes, 8 accurate
- R_u = (8/10) × log(11) = 0.8 × 2.398 = 1.918

### Weighted Trust Score
```
T_s = Σ(V_i × R_{u,i}) / Σ(R_{u,i}) × 100
```

Where:
- `V_i` = 1 for TRUE vote, 0 for FALSE vote
- `R_{u,i}` = reputation of voter i

**Example:**
- Vote 1: TRUE (V=1), Reputation=2.0
- Vote 2: TRUE (V=1), Reputation=1.5
- Vote 3: FALSE (V=0), Reputation=0.5

```
Numerator = (1 × 2.0) + (1 × 1.5) + (0 × 0.5) = 3.5
Denominator = 2.0 + 1.5 + 0.5 = 4.0
T_s = (3.5 / 4.0) × 100 = 87.5%
```

## Database Schema

### Tables

**claims**
```sql
CREATE TABLE claims (
    claim_id TEXT PRIMARY KEY,
    claim_text TEXT NOT NULL,
    ai_verdict TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_votes INTEGER DEFAULT 0
)
```

**votes**
```sql
CREATE TABLE votes (
    vote_id INTEGER PRIMARY KEY AUTOINCREMENT,
    claim_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    vote BOOLEAN NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (claim_id) REFERENCES claims(claim_id),
    UNIQUE(claim_id, user_id)
)
```

**user_reputation**
```sql
CREATE TABLE user_reputation (
    user_id TEXT PRIMARY KEY,
    total_votes INTEGER DEFAULT 0,
    accurate_votes INTEGER DEFAULT 0,
    reputation_score REAL DEFAULT 0.0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
```

## Troubleshooting

### Backend Issues

**Database not found:**
- Database is auto-created on first run
- Default location: `backend/community.db`
- For testing: uses `:memory:` database

**CORS errors:**
- Backend allows all origins in development
- For production, update CORS settings in `main.py`

### Frontend Issues

**API connection failed:**
- Ensure backend is running
- Check API URL in `community_service.dart`
- Verify CORS is enabled

**Navigation not working:**
- Check that `community_screen.dart` is imported
- Verify Navigator.push() is called correctly

## Security Notes

- Current implementation uses `demo_user` as placeholder
- Production should integrate with real authentication system
- Rate limiting should be added to vote endpoints
- Consider adding email verification for accounts
- Implement vote change cooldown period

## Performance Optimization

For production:
1. Add database indexes on frequently queried fields
2. Implement caching for top claims
3. Add pagination for large result sets
4. Consider using connection pooling for database
5. Implement periodic reputation recalculation batch job
