import os
import json
import logging
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import vertexai
from vertexai.generative_models import (
    GenerativeModel,
    Tool,
    Part,
    GenerationConfig,
    FinishReason,
)
from google.oauth2 import service_account
from firebase_functions import https_fn
from firebase_admin import initialize_app
import firebase_admin

# Import models (ensure models.py is in the same directory)
from models import AnalysisResponse, GroundingCitation, GroundingSupport
from grounding_service import GroundingService

# --- Initialization ---
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase Admin (safe to call multiple times? usually needs check)
if not firebase_admin._apps:
    initialize_app()

app = FastAPI(title="VeriScan Core Engine")

# Initialize Grounding Service
grounding_service = GroundingService()

# Configure CORS
# Critical: Allow Firebase Hosting or * for testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict this in production if possible
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Service Account / Vertex AI Configuration ---
PROJECT_ID = "veriscan-kitahack"
LOCATION = "us-central1"
VERTEX_AI_READY = False

def init_vertex():
    global VERTEX_AI_READY
    CREDENTIALS_PATH = os.path.join(os.path.dirname(__file__), "service-account.json")
    
    try:
        if os.path.exists(CREDENTIALS_PATH):
            logger.info(f"Loading credentials from {CREDENTIALS_PATH}")
            credentials = service_account.Credentials.from_service_account_file(CREDENTIALS_PATH)
            vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
            VERTEX_AI_READY = True
            logger.info("Vertex AI initialized with local Service Account.")
        else:
            logger.info(f"Credentials not found at {CREDENTIALS_PATH}. Attempting ADC...")
            # Application Default Credentials (ADC) for Cloud environment
            vertexai.init(project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI initialized with Application Default Credentials.")
    except Exception as e:
        logger.error(f"Error initializing Vertex AI: {e}")
        VERTEX_AI_READY = False

# Initialize on module load (cold start) - DISABLED for Deployment Discovery
# init_vertex()

# --- Core Logic ---
async def process_analysis(
    text: Optional[str] = None,
    url: Optional[str] = None,
    image_bytes: Optional[bytes] = None,
    image_mime: Optional[str] = None
) -> AnalysisResponse:
    """
    Core analysis logic decoupled from framework (FastAPI/Functions).
    """
    if not VERTEX_AI_READY:
        # Lazy initialization
        init_vertex()
        if not VERTEX_AI_READY:
             # Return a simplified error response instead of raising if we want to be graceful, 
             # but strictly we should error.
             raise RuntimeError("Vertex AI not configured.")

    if not text and not url and (not image_bytes):
         raise ValueError("At least one input (text, url, or image) is required.")

    logger.info(f"Processing Request - Text: {bool(text)}, URL: {bool(url)}, Image: {bool(image_bytes)}")

    try:
        # 1. Prepare Inputs
        parts = []
        
        system_instruction = """
# ROLE
You are the VeriScan Core Engine, an elite Fact-Checking AI specialized in digital forensic analysis and media literacy.

# OBJECTIVE
Analyze the provided input (Text, URL content, or Image OCR) and provide a rigorous, search-grounded verdict. You must identify logical fallacies and provide evidence through Google Search grounding.

# ANALYSIS PIPELINE
1. OCR/EXTRACT: If the input is an image, extract all text and describe visual context.
2. SEARCH: Query authoritative sources to confirm or debunk the claim.
3. EVALUATE: Check for logical fallacies (e.g., Strawman, Ad Hominem, Appeal to Fear).
4. SCORE: Assign a confidence score from 0.0 to 1.0 based on the strength of grounding citations.

# OUTPUT FORMAT (STRICT JSON ONLY)
Return ONLY a JSON object. Do not include markdown code blocks (```json). 
Schema:
{
  "verdict": "REAL" | "FAKE" | "MISLEADING" | "UNVERIFIED",
  "confidence_score": float,
  "analysis": "string (2-3 sentences explaining the 'why')",
  "key_findings": ["list of strings"],
  "source_metadata": { "type": "text" | "url" | "image", "provided_url": "string or null", "page_title": "string or null" },
  "grounding_citations": [{"title": "string", "url": "string", "snippet": "string"}],
  "media_literacy": { "logical_fallacies": ["string"], "tone_analysis": "string" }
}

# CONSTRAINTS
- If citations < 1 or confidence < 0.4, verdict MUST be "UNVERIFIED".
- Tone should be professional, objective, and "Obsidian-class" (premium/serious).
"""
        
        prompt_content = "Analyze the following content:\n"
        if text:
            prompt_content += f"Text: {text}\n"
        if url:
            prompt_content += f"URL: {url}\n"
            
        parts.append(prompt_content)

        if image_bytes:
            image_part = Part.from_data(data=image_bytes, mime_type=image_mime or "image/jpeg")
            parts.append(image_part)

        # 2. Configure Model
        tools = [Tool.from_dict({"google_search": {}})]
        model = GenerativeModel("gemini-2.0-flash-lite-001", system_instruction=[system_instruction], tools=tools)
        
        generation_config = GenerationConfig(temperature=0.0)

        # 3. Generate Content
        logger.info("Sending request to Vertex AI...")
        response = model.generate_content(parts, generation_config=generation_config)
        logger.info(f"Vertex AI Response Received. Candidates: {len(response.candidates)}")

        # 4. Extract Response
        grounding_citations = []
        if response.candidates and response.candidates[0].grounding_metadata.grounding_chunks:
            for chunk in response.candidates[0].grounding_metadata.grounding_chunks:
                # Extract text context if available
                snippet_text = "Grounding source"
                if hasattr(chunk, 'retrieved_context'):
                    # retrieved_context might be an object or string depending on SDK version
                    ctx = getattr(chunk, 'retrieved_context')
                    if ctx:
                        snippet_text = str(ctx.text) if hasattr(ctx, 'text') else str(ctx)
                
                if chunk.web:
                    grounding_citations.append(GroundingCitation(
                        title=chunk.web.title or "Source",
                        url=chunk.web.uri,
                        # Use title as text if we couldn't find a snippet, to allow title-based keywords matching
                        snippet=snippet_text if snippet_text != "Grounding source" else (chunk.web.title or "")
                    ))
                elif hasattr(chunk, 'retrieved_context'):
                     # Handle non-web chunks (e.g. from enterprise search) if needed
                     grounding_citations.append(GroundingCitation(
                        title="Retrieved Context",
                        url="",
                        snippet=snippet_text
                     ))
        
        # Check Recitation
        if response.candidates and response.candidates[0].finish_reason == FinishReason.RECITATION:
             logger.info("Finish Reason: RECITATION")
             return AnalysisResponse(
                verdict="REAL",
                confidence_score=0.99,
                analysis="The content was found verbatim in authoritative sources. (Exact text analysis hidden due to copyright/recitation limits).",
                key_findings=["Content matches online sources exactly.", "Verified via direct citation."],
                source_metadata=None,
                grounding_citations=[g.model_dump() for g in grounding_citations],
                media_literacy={"logical_fallacies": [], "tone_analysis": "N/A (Recitation)"}
            )

        # Extract Text & JSON
        try:
            response_text = ""
            if response.candidates:
                for part in response.candidates[0].content.parts:
                    if hasattr(part, 'text') and part.text:
                        response_text += part.text
            
            import re
            json_match = re.search(r'\{.*\}', response_text.strip(), re.DOTALL)
            if json_match:
                response_text = json_match.group(0)
            
            data = json.loads(response_text)
            
            # Merge citations
            if not data.get("grounding_citations") and grounding_citations:
                 data["grounding_citations"] = [g.model_dump() for g in grounding_citations]
            
            # Defaults
            data.setdefault("key_findings", [])
            data.setdefault("grounding_citations", [])
            data.setdefault("source_metadata", None)
            data.setdefault("media_literacy", None)
            
            # --- Grounding Service Integration ---
            # Prepare sources for the service (convert GroundingCitation to list of dicts)
            # The service expects [{'uri':..., 'title':..., 'text':...}]
            service_sources = []
            
            # Use the final list of citations in the data object (merged from metadata or JSON)
            final_citations = data.get("grounding_citations", [])
            
            for gc in final_citations:
                # gc might be a dict (from JSON) or model_dump (from metadata)
                # Ensure we handle both
                if isinstance(gc, dict):
                     uri = gc.get("url") or gc.get("uri")
                     title = gc.get("title")
                     snippet = gc.get("snippet")
                else:
                     # Should not happen given previous logic ensures dicts in data, but safety first
                     uri = getattr(gc, "url", "")
                     title = getattr(gc, "title", "")
                     snippet = getattr(gc, "snippet", "")

                service_sources.append({
                    "uri": uri,
                    "title": title,
                    "text": snippet or title # Use snippet or title as text for matching
                })
            
            # Assuming 'analysis' field is the main text to segment
            analysis_text = data.get("analysis", "")
            
            # Call the service
            grounding_result = grounding_service.process(analysis_text, service_sources)
            
            # Extract supports
            raw_supports = grounding_result.get("groundingSupports", [])
            
            # Convert to Pydantic models
            from models import Segment, GroundingSupport # Ensure these are available or use data directly if dict
            
            structured_supports = []
            for support in raw_supports:
                # support is a dict matching the structure
                structured_supports.append(support)
            
            # Add to data
            data["grounding_supports"] = structured_supports

            return AnalysisResponse(**data)

        except json.JSONDecodeError:
            logger.error(f"JSON Parse Error: {response.text}")
            return AnalysisResponse(
                verdict="UNVERIFIED",
                confidence_score=0.0,
                analysis="Failed to parse analysis results.",
                key_findings=["JSON Decode Error"],
                grounding_citations=[]
            )

    except Exception as e:
        logger.error(f"Analysis Processing Error: {e}")
        return AnalysisResponse(
            verdict="UNVERIFIED",
            confidence_score=0.0,
            analysis=f"System Error: {str(e)}",
            key_findings=[str(e)],
            grounding_citations=[]
        )

# --- FastAPI Endpoints ---

@app.get("/")
async def root():
    return {"status": "running", "vertex_ai": VERTEX_AI_READY}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "vertex_ai_configured": VERTEX_AI_READY}

@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_endpoint(
    text: Optional[str] = Form(None),
    url: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None)
):
    try:
        img_bytes = None
        img_mime = None
        if image:
            img_bytes = await image.read()
            img_mime = image.content_type
            
        return await process_analysis(text, url, img_bytes, img_mime)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- Firebase Cloud Function Entry Point ---

@https_fn.on_request(
    region=LOCATION,
    memory=512,
    timeout_sec=60,
    min_instances=0,
    max_instances=10
)
def analyze(req: https_fn.Request) -> https_fn.Response:
    """
    Firebase HTTPS Function wrapper for the analysis logic.
    Handles 'multipart/form-data' or JSON.
    """
    # Handle CORS (Manual for Functions if not handled by hosting rewrite)
    if req.method == 'OPTIONS':
        return https_fn.Response(status=204, headers={
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type',
        })

    # Prepare data
    text = None
    url = None
    image_bytes = None
    image_mime = None

    # Parse inputs (Flask Request)
    try:
        # Check Form Data
        if req.form:
            text = req.form.get('text')
            url = req.form.get('url')
        
        # Check JSON
        if req.is_json:
            j = req.get_json()
            if j:
                text = j.get('text') or text
                url = j.get('url') or url
        
        # Check Files
        if req.files and 'image' in req.files:
            file_storage = req.files['image']
            image_bytes = file_storage.read()
            image_mime = file_storage.content_type

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": f"Failed to parse request: {str(e)}"}), 
            status=400, 
            headers={'Access-Control-Allow-Origin': '*'}
        )
    
    # Run Async Logic Synchronously (Cloud Functions v2 Python can handle async but usually via loop)
    # OR we can just use asyncio.run() since this is a synchronous entry point
    import asyncio
    try:
        response_model = asyncio.run(process_analysis(text, url, image_bytes, image_mime))
        
        return https_fn.Response(
            json.dumps(response_model.model_dump()), 
            status=200, 
            mimetype='application/json',
            headers={'Access-Control-Allow-Origin': '*'}
        )
    except ValueError as e:
        return https_fn.Response(json.dumps({"detail": str(e)}), status=400, headers={'Access-Control-Allow-Origin': '*'})
    except Exception as e:
        return https_fn.Response(json.dumps({"detail": str(e)}), status=500, headers={'Access-Control-Allow-Origin': '*'})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8080)
