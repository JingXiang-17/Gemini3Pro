import os
import json
from typing import Optional, List
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import vertexai
from vertexai.generative_models import (
    GenerativeModel,
    Tool,
    GenerationConfig,
    HarmCategory,
    HarmBlockThreshold,
    grounding
)
from google.oauth2 import service_account

# Load environment variables
load_dotenv()

app = FastAPI(title="Fake News Detector API")

# Configure CORS for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Service Account Configuration ---
CREDENTIALS_PATH = r"C:\Users\User\Documents\Gemini3Pro\backend\service-account.json"
PROJECT_ID = "veriscan-kitahack"
LOCATION = "us-central1"

try:
    if os.path.exists(CREDENTIALS_PATH):
        credentials = service_account.Credentials.from_service_account_file(CREDENTIALS_PATH)
        vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
        VERTEX_AI_READY = True
        print(f"Vertex AI initialized from: {CREDENTIALS_PATH}")
    else:
        print(f"CRITICAL: Credentials not found at {CREDENTIALS_PATH}")
        VERTEX_AI_READY = False
except Exception as e:
    print(f"Error initializing Vertex AI: {e}")
    VERTEX_AI_READY = False


class NewsRequest(BaseModel):
    news_text: str  # Aligned with Swagger and Prompt


class NewsResponse(BaseModel):
    is_valid: bool
    confidence_score: float
    analysis: str
    key_findings: List[str]


@app.get("/")
async def root():
    return {
        "message": "Fake News Detector API (Hackathon Optimized)",
        "status": "running"
    }


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "vertex_ai_configured": VERTEX_AI_READY,
        "model": "gemini-2.5-flash-lite"
    }


@app.post("/analyze", response_model=NewsResponse)
async def analyze_news(request: NewsRequest):
    """
    Analyze news article using Gemini 2.5 Flash-Lite.
    Handles multi-part responses and enforces strict JSON output.
    """
    if not VERTEX_AI_READY:
        raise HTTPException(status_code=500, detail="Vertex AI not configured.")
    
    try:
        # Grounding Tool
        search_tool = Tool.from_dict({"google_search": {}})
        model = GenerativeModel("gemini-2.5-flash-lite", tools=[search_tool])
        
        # Strict System Prompt
        prompt = f"""You are a strict fact-checker. Analyze the provided news_text and output ONLY a valid JSON object. 
Do not include a conversational preamble, thought process, or markdown blocks. 
Focus only on the provided news_text.

NEWS ARTICLE:
{request.news_text}

Output format:
{{
  "verdict": "REAL" | "FAKE" | "UNCERTAIN",
  "confidence": number,
  "analysis": "string",
  "key_findings": ["string", "string", "string"]
}}
"""

        generation_config = GenerationConfig(
            temperature=0.0, 
            max_output_tokens=2048,
        )
        safety_settings = {
            HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
        }

        response = model.generate_content(
            prompt,
            generation_config=generation_config,
            safety_settings=safety_settings
        )
        
        # --- Multi-Part Part Extraction ---
        full_text = ""
        try:
            if response.candidates:
                candidate = response.candidates[0]
                if candidate.content and candidate.content.parts:
                    for part in candidate.content.parts:
                        if hasattr(part, 'text') and part.text:
                            full_text += part.text
        except Exception as e:
            # Silent fallback
            try:
                full_text = response.text
            except:
                full_text = ""

        # --- JSON Cleaning ---
        clean_text = full_text.strip()
        if clean_text.startswith("```json"):
            clean_text = clean_text.split("```json")[1].split("```")[0].strip()
        elif clean_text.startswith("```"):
            clean_text = clean_text.split("```")[1].split("```")[0].strip()
        
        # Fallback: find first { and last }
        if "{" in clean_text and "}" in clean_text:
            start = clean_text.find("{")
            r_end = clean_text.rfind("}") + 1
            clean_text = clean_text[start:r_end]

        if not clean_text:
            return NewsResponse(
                is_valid=False,
                confidence_score=0.0,
                analysis="Gemini returned an empty response. This might be due to safety filters or a temporary glitch.",
                key_findings=["Empty response"]
            )

        try:
            result = json.loads(clean_text)
            
            return NewsResponse(
                is_valid=result.get("verdict") == "REAL",
                confidence_score=float(result.get("confidence", 50.0)),
                analysis=result.get("analysis", "No analysis provided."),
                key_findings=result.get("key_findings", [])
            )
        except Exception as parse_err:
            print(f"Parse error: {parse_err}. Raw: {full_text}")
            return NewsResponse(
                is_valid=False,
                confidence_score=0.0,
                analysis=f"Failed to parse model response. Raw: {full_text[:200]}...",
                key_findings=["Parsing error"]
            )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
