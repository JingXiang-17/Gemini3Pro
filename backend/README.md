# Fake News Detector Backend

This is the Python/FastAPI backend for the Fake News Detector app, powered by Google's Gemini AI API.

## Features

- **Strict Fact-Checking**: Uses Gemini AI with low temperature (0.1) to ensure strict validation of numbers, names, dates, and crucial information
- **Grammar-Lenient**: Focuses on meaning rather than perfect grammar or spelling
- **RESTful API**: FastAPI endpoints for news analysis
- **CORS Enabled**: Ready for Flutter frontend integration

## Setup

1. **Install Python dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure Gemini API Key**:
   - Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a `.env` file in the backend directory:
     ```bash
     cp .env.example .env
     ```
   - Add your API key to the `.env` file:
     ```
     GEMINI_API_KEY=your_actual_api_key_here
     ```

3. **Run the server**:
   ```bash
   # From the backend directory
   python main.py
   
   # Or using uvicorn directly
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

4. **Test the API**:
   - Open http://localhost:8000 in your browser
   - API documentation: http://localhost:8000/docs
   - Health check: http://localhost:8000/health

## API Endpoints

### `GET /`
Root endpoint with API information.

### `GET /health`
Health check endpoint to verify API status and Gemini AI configuration.

### `POST /analyze`
Analyze news article for validity.

**Request Body**:
```json
{
  "news_text": "Your news article text here..."
}
```

**Response**:
```json
{
  "is_valid": true,
  "confidence_score": 85.0,
  "analysis": "Detailed analysis of the news article...",
  "key_findings": [
    "Finding 1",
    "Finding 2",
    "Finding 3"
  ]
}
```

## Configuration

The Gemini AI model is configured with:
- **Temperature: 0.1** - Low temperature for strict, factual responses
- **Model: gemini-1.5-pro** - Advanced model for nuanced analysis
- Focus on factual accuracy (numbers, names, dates) over grammar/spelling

## Example Usage

```bash
curl -X POST "http://localhost:8000/analyze" \
  -H "Content-Type: application/json" \
  -d '{
    "news_text": "Breaking: Scientists discover new planet with 3 moons orbiting Alpha Centauri"
  }'
```
