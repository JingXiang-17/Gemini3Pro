import os
import json
import logging
import base64
import httpx
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
    HarmCategory,
    HarmBlockThreshold
)
from google.oauth2 import service_account
from firebase_functions import https_fn
from firebase_admin import initialize_app
import firebase_admin

# Import models
from models import AnalysisRequest, AnalysisResponse, GroundingCitation, GroundingSupport

# Import community routes
from community_routes import router as community_router

# --- Initialization ---
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if not firebase_admin._apps:
    initialize_app()

app = FastAPI(title="VeriScan Core Engine")
_grounding_service = None

# Register community routes
app.include_router(community_router)

def get_grounding_service():
    global _grounding_service
    if _grounding_service is None:
        from grounding_service import GroundingService
        _grounding_service = GroundingService()
    return _grounding_service

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Vertex AI Configuration ---
PROJECT_ID = os.getenv("PROJECT_ID", "veriscan-kitahack")
LOCATION = os.getenv("LOCATION", "us-central1")
VERTEX_AI_READY = False

def init_vertex():
    global VERTEX_AI_READY
    base_dir = os.path.dirname(os.path.abspath(__file__))
    CREDENTIALS_PATH = os.path.join(base_dir, "service-account.json")
    
    try:
        env_creds = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if env_creds and os.path.exists(env_creds):
            vertexai.init(project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI initialized via environment variable.")
        elif os.path.exists(CREDENTIALS_PATH):
            credentials = service_account.Credentials.from_service_account_file(CREDENTIALS_PATH)
            vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
            VERTEX_AI_READY = True
            logger.info(f"Vertex AI initialized with bundled Service Account: {CREDENTIALS_PATH}")
        else:
            vertexai.init(project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI initialized with Application Default Credentials.")
    except Exception as e:
        logger.error(f"FATAL: Vertex AI Initialization Failed: {e}")
        VERTEX_AI_READY = False

# --- 1. Helper Functions (From Main) ---
async def fetch_url_content(url: str) -> str:
    """Fetches text content from a URL."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            return response.text[:5000]
    except Exception as e:
        logger.error(f"Error fetching URL {url}: {e}")
        return f"[Error fetching content from {url}]"

# --- 2. Core Logic (Hybrid: Structure from Main, Brains from KJV) ---
async def process_multimodal_gemini(gemini_parts: List[Any], request_id: str, file_names: List[str] = None) -> AnalysisResponse:
    """Core logic to execute Gemini analysis."""
    if not VERTEX_AI_READY:
        init_vertex()
        if not VERTEX_AI_READY:
            raise RuntimeError("Credentials file not found or Vertex AI configuration invalid.")

    logger.info(f"Processing Analysis Request: {request_id}")
    file_names = file_names or []

    try:
        # --- YOUR OPTIMIZED OPINION-PROOF PROMPT ---
        system_instruction = """
        Role: VeriScan Core Engine.
        
        CRITICAL ANALYSIS PROTOCOL (FOLLOW IN ORDER):
        
        PHASE 1: CLASSIFICATION (The Gatekeeper)
        - Analyze the input for Subjectivity, Opinions, Insults, or Satire.
        - EXAMPLES:
          * "Politician X is corrupt" -> Fact Check required (Check court cases).
          * "Politician X is stupid/ugly/pointless" -> OPINION (Subjective).
        - IF OPINION/INSULT: STOP immediately. Proceed to generate JSON with the below rules. 
          * VERDICT MUST BE: "UNVERIFIED".
          * VERDICT CANNOT BE: "FAKE" or "FALSE".
          * Analysis: "This statement is a subjective opinion or insult. Opinions cannot be proven true or false."
        
        PHASE 2: TYPO CORRECTION (Implicit)
        - If Input is factual (e.g. "Malausia"), correct typos internally before searching.
        - DO NOT correct numbers/dates.
        
        PHASE 3: FACT CHECKING (Only for Factual Claims)
        - Perform a Google Search.
        - If the claim contradicts established facts, Verdict is "FAKE".
        - If the claim is supported by facts, Verdict is "REAL".
        - If the claim is partially true/missing context, Verdict is "MISLEADING".
        
        Output: STRICT JSON only. No Markdown.
        Format:
        {
          "verdict": "REAL" | "FAKE" | "MISLEADING" | "UNVERIFIED",
          "confidence_score": 0.0 to 1.0,
          "analysis": "string (2-3 sentences)",
          "key_findings": ["string"],
          "media_literacy": { "logical_fallacies": ["string"], "tone_analysis": "string" }
        }
        
        IMPORTANT: Do NOT include a 'grounding_citations' list in your JSON. The system will add them automatically.
        """

        tools = [Tool.from_dict({"google_search": {}})]
        model = GenerativeModel("gemini-2.0-flash-lite-001", system_instruction=[system_instruction], tools=tools)
        
        # Safety Settings
        safety_settings = {
            HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
            HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_ONLY_HIGH,
        }

        # Generate
        response = model.generate_content(
            gemini_parts,
            generation_config=GenerationConfig(temperature=0.0),
            safety_settings=safety_settings
        )
        
        # --- Response Processing (Hybrid) ---
        
        # 1. Extract Google Search Citations (Grounding)
        grounding_citations = []
        if response.candidates and response.candidates[0].grounding_metadata.grounding_chunks:
            for chunk in response.candidates[0].grounding_metadata.grounding_chunks:
                if chunk.web:
                    grounding_citations.append(GroundingCitation(
                        title=chunk.web.title or "Source",
                        url=chunk.web.uri or "No link",
                        snippet="Verified via Google Search"
                    ))

        # 2. Extract JSON Text
        response_text = ""
        try:
            if response.candidates:
                for part in response.candidates[0].content.parts:
                    if part.text: response_text += part.text
        except:
            response_text = response.text

        response_text = response_text.replace("```json", "").replace("```", "").strip()

        # 3. Parse JSON
        import re
        try:
            # Check if response is empty
            if not response_text or len(response_text) == 0:
                logger.error("Empty response from Gemini API")
                data = {
                    "verdict": "UNVERIFIED",
                    "confidence_score": 0.0,
                    "analysis": "Unable to analyze: The AI service returned an empty response. This usually indicates an authentication or configuration issue.",
                    "key_findings": ["Empty AI response - check Google Cloud credentials"]
                }
            else:
                match = re.search(r'\{[\s\S]*\}', response_text)
                if match: response_text = match.group(0)
                
                data = json.loads(response_text)
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON Parse Failed. Raw Text: {response_text[:200]}...")
            logger.error(f"JSON Decode Error: {str(e)}")
            data = {
                "verdict": "UNVERIFIED",
                "confidence_score": 0.0,
                "analysis": "Unable to process AI response: The response format was not valid JSON. This may be due to authentication issues with Google Cloud.",
                "key_findings": ["AI response format error - check Google Cloud configuration"]
            }

        # 4. Merge Citations
        # If the prompt generated citations (it shouldn't, per instructions), ignore them
        # and use the real Google Tool citations
        data["grounding_citations"] = [c.model_dump() for c in grounding_citations]
        
        if "source_metadata" not in data: data["source_metadata"] = None
        if "media_literacy" not in data: data["media_literacy"] = None

        print(f"✅ Verdict: {data.get('verdict')} | Citations: {len(data['grounding_citations'])}")
        return AnalysisResponse(**data)

    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        logger.error(f"Analysis Processing Error: {e}")
        logger.error(f"Stack trace: {error_trace}")
        
        # Provide friendly error message based on error type
        error_msg = str(e)
        if "credentials" in error_msg.lower() or "authentication" in error_msg.lower():
            friendly_msg = "Google Cloud authentication is not configured. Please set up Application Default Credentials or provide a service account key."
            finding = "Missing Google Cloud credentials"
        elif "permission" in error_msg.lower() or "access" in error_msg.lower():
            friendly_msg = "Permission denied: Your Google Cloud account doesn't have access to Vertex AI. Please check IAM permissions."
            finding = "Insufficient permissions for Vertex AI"
        else:
            friendly_msg = f"An unexpected error occurred during analysis: {error_msg}"
            finding = error_msg
        
        return AnalysisResponse(
            verdict="UNVERIFIED",
            confidence_score=0.0,
            analysis=friendly_msg,
            key_findings=[finding],
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
    files: Optional[List[UploadFile]] = File(None),
    metadata: str = Form(...)
):
    try:
        try:
            meta_data = json.loads(metadata)
        except json.JSONDecodeError:
            # Fallback for simple form data (legacy support for Android)
            meta_data = {"text_claim": metadata}
        
        request_id = meta_data.get("request_id", "unknown")
        text_claim = meta_data.get("text_claim")
        provided_url = meta_data.get("url")
        provided_urls = meta_data.get("urls", [])
        
        gemini_parts = []
        prompt_content = "Analyze the following parts (Text, Images, Documents, URLs):\n\n"
        
        if text_claim:
            prompt_content += f"TEXT CLAIM: {text_claim}\n"
        
        # Process URLs (using helper from Main)
        if provided_url:
            content = await fetch_url_content(provided_url)
            prompt_content += f"URL CONTENT (from {provided_url}):\n{content}\n"
        
        for url in provided_urls:
            content = await fetch_url_content(url)
            prompt_content += f"URL CONTENT (from {url}):\n{content}\n"
        
        total_size = len(metadata)
        file_names = []
        if files:
            for file in files:
                file_bytes = await file.read()
                file_size = len(file_bytes)
                
                if file_size > 10 * 1024 * 1024:
                    raise HTTPException(status_code=413, detail=f"File {file.filename} exceeds 10MB limit.")
                
                total_size += file_size
                file_names.append(file.filename)
                mime_type = file.content_type or "application/octet-stream"
                part_args = {"data": file_bytes, "mime_type": mime_type}
                
                if "image" in mime_type:
                    gemini_parts.append(Part.from_data(**part_args))
                    prompt_content += f"[Image Attached: {file.filename}]\n"
                elif mime_type == "application/pdf":
                    gemini_parts.append(Part.from_data(**part_args))
                    prompt_content += f"[PDF Document Attached: {file.filename}]\n"

        if total_size > 20 * 1024 * 1024:
             raise HTTPException(status_code=413, detail="Total payload size exceeds 20MB limit.")

        gemini_parts.insert(0, prompt_content)
        
        # Call the core logic function
        return await process_multimodal_gemini(gemini_parts, request_id, file_names)
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- Firebase Cloud Function Wrapper (From Main Branch) ---
# This allows deployment to Google Cloud Functions
@https_fn.on_request(
    region=LOCATION,
    memory=512,
    timeout_sec=60,
    min_instances=0,
    max_instances=10
)
def analyze(req: https_fn.Request) -> https_fn.Response:
    if req.method == 'OPTIONS':
        return https_fn.Response(status=204, headers={
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        })

    if req.method != 'POST':
        return https_fn.Response("Method Not Allowed. Use POST.", status=405, headers={'Access-Control-Allow-Origin': '*'})

    import asyncio
    import traceback
    
    try:
        metadata_str = req.form.get("metadata")
        if not metadata_str:
             return https_fn.Response(json.dumps({"error": "Missing metadata field"}), status=400, mimetype='application/json')
        
        meta_data = json.loads(metadata_str)
        request_id = meta_data.get("request_id", "prod_req")
        text_claim = meta_data.get("text_claim", "")
        provided_urls = meta_data.get("urls", [])
        
        gemini_parts = []
        prompt_content = f"Analyze the following parts (Text, Images, Documents, URLs):\n\nTEXT CLAIM: {text_claim}\n"
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        async def _run():
            nonlocal prompt_content
            for url in provided_urls:
                content = await fetch_url_content(url)
                prompt_content += f"URL CONTENT (from {url}):\n{content}\n"
            
            file_names = []
            for key in req.files:
                for f in req.files.getlist(key):
                    file_bytes = f.read()
                    if not file_bytes: continue
                    file_names.append(f.filename)
                    mime_type = f.content_type or "application/octet-stream"
                    part_args = {"data": file_bytes, "mime_type": mime_type}
                    if "image" in mime_type:
                        gemini_parts.append(Part.from_data(**part_args))
                        prompt_content += f"[Image Attached: {f.filename}]\n"
                    elif mime_type == "application/pdf":
                        gemini_parts.append(Part.from_data(**part_args))
                        prompt_content += f"[PDF Document Attached: {f.filename}]\n"

            gemini_parts.insert(0, prompt_content)
            return await process_multimodal_gemini(gemini_parts, request_id, file_names)

        try:
            result = loop.run_until_complete(_run())
            return https_fn.Response(
                json.dumps(result.model_dump()),
                status=200,
                mimetype='application/json',
                headers={'Access-Control-Allow-Origin': '*'}
            )
        finally:
            loop.close()

    except Exception as e:
        error_msg = f"ERROR: {str(e)}\n{traceback.format_exc()}"
        logger.error(f"Function Execution Error: {error_msg}")
        return https_fn.Response(json.dumps({
            "error": "Internal Server Error during forensic analysis.",
            "debug_trace": error_msg
        }), status=500, mimetype='application/json', headers={'Access-Control-Allow-Origin': '*'})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)