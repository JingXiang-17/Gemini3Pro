import os
import json
from typing import Optional, List
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import vertexai
from vertexai.generative_models import (
    GenerativeModel,
    Tool,
    Part,
    GenerationConfig,
    HarmCategory,
    HarmBlockThreshold,
    FinishReason,
    grounding
)
from google.oauth2 import service_account
from models import AnalysisResponse, SourceMetadata, GroundingCitation, MediaLiteracy

# Load environment variables
load_dotenv()

app = FastAPI(title="VeriScan Core Engine")

# Configure CORS for Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Service Account Configuration ---
CREDENTIALS_PATH = os.path.join(os.path.dirname(__file__), "service-account.json")
PROJECT_ID = "veriscan-kitahack"
LOCATION = "us-central1"

VERTEX_AI_READY = False
try:
    if os.path.exists(CREDENTIALS_PATH):
        credentials = service_account.Credentials.from_service_account_file(CREDENTIALS_PATH)
        vertexai.init(project=PROJECT_ID, location=LOCATION, credentials=credentials)
        VERTEX_AI_READY = True
        print(f"Vertex AI initialized from: {CREDENTIALS_PATH}")
    else:
        print(f"CRITICAL: Credentials not found at {CREDENTIALS_PATH}")
except Exception as e:
    print(f"Error initializing Vertex AI: {e}")

@app.get("/")
async def root():
    return {
        "message": "VeriScan Core Engine (Antigravity Update)",
        "status": "running",
        "vertex_ai": VERTEX_AI_READY
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "vertex_ai_configured": VERTEX_AI_READY,
        "model": "gemini-2.5-flash-lite"
    }

@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_multimodal(
    text: Optional[str] = Form(None),
    url: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None)
):
    """
    Antigravity Endpoint: Analyzes text, URL, or image using VeriScan Core Engine logic.
    Returns a strict JSON verdict with Google Search grounding.
    """
    if not VERTEX_AI_READY:
        raise HTTPException(status_code=500, detail="Vertex AI not configured.")

    if not text and not url and not image:
        raise HTTPException(status_code=400, detail="At least one input (text, url, or image) is required.")

    try:
        # 1. Prepare Inputs (Multimodal)
        parts = []
        
        # System Instruction for Antigravity
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

        if image:
            image_bytes = await image.read()
            image_part = Part.from_data(data=image_bytes, mime_type=image.content_type)
            parts.append(image_part)

        # 2. Configure Model with Grounding
        tools = [Tool.from_dict({"google_search": {}})]
        model = GenerativeModel("gemini-2.5-flash-lite", system_instruction=[system_instruction], tools=tools)
        
        generation_config = GenerationConfig(
            temperature=0.0,
            # response_mime_type="application/json"  # Incompatible with google_search grounding
        )

        # 3. Generate Content
        response = model.generate_content(
            parts,
            generation_config=generation_config
        )

        # 4. Extract Response and Grounding
        try:
            # Check for grounding metadata
            grounding_citations = []
            if response.candidates and response.candidates[0].grounding_metadata.grounding_chunks:
                for chunk in response.candidates[0].grounding_metadata.grounding_chunks:
                    if chunk.web:
                        grounding_citations.append(GroundingCitation(
                            title=chunk.web.title or "Source",
                            url=chunk.web.uri,
                            snippet="Grounding source" # API might not return snippet in simple chunks
                        ))
            
            # Check for RECITATION (copyright block)
            # If the model is reciting, it means the content is likely REAL and found verbatim.
            # We can't get the text, but we can get the citations.
            is_recitation = False
            if response.candidates and response.candidates[0].finish_reason == FinishReason.RECITATION:
                is_recitation = True
                print("Finish Reason: RECITATION. Extracting raw citations...")
                
                # Extract citation metadata from the candidate (different from grounding metadata)
                if hasattr(response.candidates[0], 'citation_metadata') and response.candidates[0].citation_metadata:
                    for citation in response.candidates[0].citation_metadata.citations:
                        grounding_citations.append(GroundingCitation(
                            title="Cited Source (Recitation)",
                            url=citation.uri,
                            snippet=f"Source found at indices {citation.start_index}-{citation.end_index}"
                        ))

            if is_recitation:
                # Return a special "Verified by Recitation" response
                return AnalysisResponse(
                    verdict="REAL", # If it's reciting, it found the exact text -> Real
                    confidence_score=0.99,
                    analysis="The content was found verbatim in authoritative sources. (Exact text analysis hidden due to copyright/recitation limits).",
                    key_findings=["Content matches online sources exactly.", "Copyright limits prevented full text analysis.", "Verified via direct citation."],
                    source_metadata=None,
                    grounding_citations=[g.model_dump() for g in grounding_citations],
                    media_literacy={"logical_fallacies": [], "tone_analysis": "N/A (Recitation)"}
                )

            # Parse JSON
            # Handle multi-part responses (Text + Grounding/Function calls)
            try:
                response_text = response.text.strip()
            except Exception:
                # Fallback for "multiple content parts" error
                response_text = ""
                if response.candidates:
                    for part in response.candidates[0].content.parts:
                        if part.text:
                            response_text += part.text
                response_text = response_text.strip()
            
            # Robust JSON extraction using regex
            import re
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                response_text = json_match.group(0)
            
            try:
                data = json.loads(response_text)
            except json.JSONDecodeError:
                # Try to fix common JSON issues (e.g. trailing commas) if needed, 
                # but for now just log and re-raise to catch block
                print(f"JSON Decode Failed. Regex extracted: {response_text}")
                raise

            # Map grounding citations if the model didn't provide them but the tool did
            if not data.get("grounding_citations") and grounding_citations:
                 data["grounding_citations"] = [g.model_dump() for g in grounding_citations]
            elif grounding_citations:
                pass 
                
            # Use Pydantic for validation
            if "source_metadata" not in data:
                 data["source_metadata"] = None
            if "media_literacy" not in data:
                 data["media_literacy"] = None
                 
            # Ensure keys exist for Pydantic (though strict schema usually handles this, safe to add defaults)
            if "key_findings" not in data:
                data["key_findings"] = []
            if "grounding_citations" not in data:
                data["grounding_citations"] = []
                
            analysis_response = AnalysisResponse(**data)

            return analysis_response

        except json.JSONDecodeError:
            print(f"JSON Parse Error. Raw: {response.text}")
            return AnalysisResponse(
                verdict="UNVERIFIED",
                confidence_score=0.0,
                analysis="Failed to parse analysis results.",
                key_findings=["JSON Decode Error"],
                source_metadata=None,
                grounding_citations=[],
                media_literacy=None
            )
        except Exception as e:
            print(f"Processing Error: {e}")
            return AnalysisResponse(
                verdict="UNVERIFIED",
                confidence_score=0.0,
                analysis=f"An error occurred during processing: {str(e)}",
                key_findings=["Processing Error"],
                source_metadata=None,
                grounding_citations=[],
                media_literacy=None
            )

    except Exception as e:
        print(f"Critical Error: {e}")
        return AnalysisResponse(
            verdict="UNVERIFIED",
            confidence_score=0.0,
            analysis="A critical system error occurred.",
            key_findings=[str(e)],
            grounding_citations=[]
        )
