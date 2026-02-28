import os
import re
import json
import logging
import base64
import httpx
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, responses
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from google import genai
from google.genai import types
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
genai_client = None
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
    allow_origins=[
        "http://localhost",
        "http://localhost:8080",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:8080",
        # Firebase Hosting production domains
        "https://veriscan-kitahack.web.app",
        "https://veriscan-kitahack.firebaseapp.com",
    ],
    allow_origin_regex=r"https://.*\.app\.github\.dev|http://localhost:.*|https://.*\.web\.app|https://.*\.firebaseapp\.com",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(413)
async def request_too_large_handler(request, exc):
    return JSONResponse(
        status_code=413,
        content={"error": "File Size Limit Exceeded. Please ensure individual files are under 20MB and total upload is under 50MB."}
    )

# --- Vertex AI Configuration ---
PROJECT_ID = os.getenv("PROJECT_ID", "veriscan-kitahack")
LOCATION = os.getenv("LOCATION", "us-central1")
VERTEX_AI_READY = False

def init_vertex():
    global VERTEX_AI_READY, genai_client
    # Robust absolute pathing for production
    base_dir = os.path.dirname(os.path.abspath(__file__))
    CREDENTIALS_PATH = os.path.join(base_dir, "service-account.json")
    
    try:
        env_creds = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if env_creds and os.path.exists(env_creds):
            genai_client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI Client (google-genai) initialized via environment variable.")
        elif os.path.exists(CREDENTIALS_PATH):
            # The new SDK can use os.environ to find credentials if we set it temporarily or just use it
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = CREDENTIALS_PATH
            genai_client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info(f"Vertex AI Client (google-genai) initialized with bundled Service Account: {CREDENTIALS_PATH}")
        else:
            # Fallback to default credentials (works on some GCP environments)
            genai_client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)
            VERTEX_AI_READY = True
            logger.info("Vertex AI Client (google-genai) initialized with Application Default Credentials.")
    except Exception as e:
        logger.error(f"FATAL: Vertex AI (google-genai) Initialization Failed: {e}")
        VERTEX_AI_READY = False

def normalize_for_search(text: str) -> str:
    """Normalizes text for robust anchor matching (degree symbols, spaces, etc)."""
    if not text:
        return ""
    # Standardize degree symbol: handles standard, escaped, and common corruption variants
    # Note: the empty string in replace('', '°') was likely a placeholder for a specific corruption char
    # We'll use the specific ones mentioned and general cleanup.
    normalized = text.replace('\\u00b0', '°').replace('â°', '°').strip()
    return normalized

def repair_and_parse_json(raw_text: str) -> dict:
    """Aggressively cleans and parses LLM-generated JSON."""
    if not raw_text:
        raise ValueError("Empty response text")

    # 4. Hardened Cleaning (The "Strip" Method): 
    # Use a Regex to find the first { and the last } and ignore everything else.
    json_match = re.search(r'\{.*\}', raw_text, re.DOTALL)
    if not json_match:
        raise ValueError("No JSON object found in text")

    cleaned = json_match.group(0)

    # Attempt to fix trailing commas before closing braces/brackets
    cleaned = re.sub(r',\s*([\]}])', r'\1', cleaned)

    # Fallback to targeted regex for escaping double quotes inside the "analysis" text specifically.
    # LLMs frequently hallucinate unescaped double quotes when writing long analysis paragraphs.
    try:
        return json.loads(cleaned, strict=False)
    except json.JSONDecodeError:
        # If the first standard parse fails, let's aggressively escape just the analysis block
        # Match "analysis": " (everything here) " , "multimodal_cross_check"
        match = re.search(r'("analysis"\s*:\s*")(.*?)("\s*,\s*"multimodal_cross_check")', cleaned, re.DOTALL)
        if match:
            analysis_text = match.group(2)
            # Escape inner quotes
            escaped_text = analysis_text.replace('"', '\\"')
            # Reconstruct string
            cleaned = cleaned[:match.start(2)] + escaped_text + cleaned[match.end(2):]
            
        return json.loads(cleaned, strict=False)

def sanitize_grounding_text(text: str) -> str:
    """Strips JSON structural fragments from cited segments using aggressive multiline logic."""
    if not text:
        return ""
    
    # 1. Pre-strip code block artifacts
    text = text.replace("```json", "").replace("```", "").strip()
    
    # 2. Line-by-line cleanup for structural leakage
    lines = text.splitlines()
    cleaned_lines = []
    
    # Pattern for JSON keys: "verdict": or \"analysis\": or key_findings: [ 
    # Handles escaped quotes commonly found in leaked segments
    key_pattern = re.compile(r'^\s*(?:\\")?"?([\w_]+)(?:\\")?"?\s*:\s*', re.IGNORECASE)
    # Pattern for solo structural bits or boolean leaks
    structure_pattern = re.compile(r'^\s*[{}[\],"\\]+\s*$|^\s*(?:\\")?"?(?:true|false)(?:\\")?"?\s*,?\s*$', re.IGNORECASE)
    # Keys to skip entirely (structural/forensic metadata)
    metadata_keys = {"verdict", "confidence_score", "multimodal_cross_check", "type", "provided_url", "page_title"}

    for line in lines:
        s_line = line.strip()
        if not s_line:
            continue
            
        # If the line is a key pattern
        match = key_pattern.match(s_line)
        if match:
            key_name = match.group(1).lower()
            # If it's a metadata key, skip the entire line/value
            if key_name in metadata_keys:
                continue
                
            # If it's a content key (like "analysis"), try to take the value
            if ":" in s_line:
                value_part = s_line.split(":", 1)[1].strip().strip('",\\ ')
                if value_part and not structure_pattern.match(value_part):
                    # Value contains actual text, keep only the value!
                    cleaned_lines.append(value_part)
            continue
            
        # If it's just structural junk, skip it entirely
        if structure_pattern.match(s_line):
            continue
            
        # Otherwise, it's likely real content
        cleaned_lines.append(line)

    text = "\n".join(cleaned_lines).strip()
    
    # 3. Final cleanup of leading/trailing structural junk
    text = text.strip('"{},[] \n\r\t')
    # Remove trailing quotes and commas again after stripping
    text = re.sub(r'["\s,\]}\\]*$', '', text)
    
    return text.strip()

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

def normalize_url(url: str) -> str:
    """Normalizes a URL for comparison by removing protocol, www, and trailing slashes."""
    if not url:
        return ""
    # Strip protocol
    url = re.sub(r'^https?://', '', url.lower())
    # Strip www.
    url = re.sub(r'^www\.', '', url)
    # Strip trailing slash
    url = url.rstrip('/')
    # Strip query params/fragments for aggressive matching if needed, 
    # but for now let's keep it simple
    return url

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
You are the VeriScan Skeptical Fact-Checking Analyst and Lead Forensic Auditor. Your job is to analyze claims with extreme skepticism, treating all user-provided data as unverified until cross-referenced with external authorities.

### HANDLING USER UPLOADS:
- Treat all information in uploaded files (PDFs, Images, Text) as **Unverified Claims**, not as factual sources.
- **Strict Rule:** Never use an uploaded file as a citation to prove its own contents. You MUST seek independent verification.

### GROUNDING WORKFLOW & RULE OF ENGAGEMENT:
1. **Identify Claims:** Extract the core factual claims from the user's uploaded file or text.
2. **External Verification:** Use the Google Search tool to find independent, external sources (news, government data, academic papers) that either support or refute those claims.
3. **Citation Mandate:** Only cite URLs and snippets from the independent Google Search results in your final "Evidence" section. 
4. **Logic Engine:** 
    - If search results match the file: **Verified/True**. 
    - If search results conflict with the file: **Fake/False**. 
    - If no independent external evidence is found: **Unverified/Unverifiable**.
5. ZERO HALLUCINATION: You must base your analysis entirely on the provided 'Grounding Metadata' (Search Results) and the user's uploaded files/URLs. Do not use outside knowledge.
6. NO ASSUMPTIONS: If the grounding data does not explicitly confirm or deny a claim, you must categorize the verdict as "UNVERIFIABLE".
7. VERDICT HIERARCHY:
    - TRUE: 100% of the claim is factual based on external evidence.
    - MOSTLY_TRUE: The core claim is factual but contains a minor scientific technicality or rounding error.
    - MIXTURE: Use this if the input contains multiple facts where at least one is TRUE and at least one is FALSE, OR if there is a conflict between an uploaded file and a live search result. (e.g., "A is true and B is false" = MIXTURE).
    - MISLEADING: The facts are technically true but presented in a way that implies a false conclusion.
    - MOSTLY_FALSE: The core claim is false but contains a minor element of truth.
    - FALSE: The core claim is refuted by external search results.
    - UNVERIFIABLE: Insufficient independent grounding data exists.
    - NOT_A_CLAIM: Subjective, opinion, or future prediction.
8. MULTIMODAL CROSS-EXAMINATION & OUTER SEARCH: You must perform a live grounding search for every claim to cross-reference user-provided files with external real-time data. Even if a user-provided file (PDF/Image) seems sufficient, you MUST seek external authoritative sources (Google Search, IFCN, Govt Databases) to verify the current status as of February 28, 2026. 
9. LITERAL FACT-CHECKING & NO INTERNAL BIAS: You must evaluate the literal physical reality of the claim. Do not rely solely on internal knowledge for "Current" facts. If you find a conflict between a user file and a live search result, cite both sources. If a user claims an absurd or impossible entity exists, you must fact-check its physical existence.
10. IDENTIFYING NON-CLAIMS (SHORT-CIRCUIT): You can only fact-check objective, verifiable statements of past or present fact. If the user's input is a subjective opinion, a prediction of the future, a question, or a poem, you must immediately classify the verdict as "NOT_A_CLAIM".
11. MANDATORY SNIPPETS: For every single entry in grounding_citations, you MUST provide a direct, non-null snippet. For PDFs/URLs, provide a 1-2 sentence verbatim quote. For Images, provide a specific description of the visual evidence found.
12. TONE: Maintain an objective, journalistic, and highly analytical tone. Avoid emotional language.

### REQUIRED OUTPUT FORMAT:
You MUST return your final response strictly as a valid JSON object matching the exact structure below. Do NOT wrap the JSON in markdown code blocks (like ```json). Ensure all internal double quotes are escaped (e.g., \") as per standard JSON rules.

{
  "verdict": "TRUE | MOSTLY_TRUE | MIXTURE | MISLEADING | MOSTLY_FALSE | FALSE | UNVERIFIABLE | NOT_A_CLAIM",
  "confidence_score": [float between 0.0 and 1.0 representing AI reasoning certainty],
  "analysis": "[A highly detailed markdown-formatted string following the exact structure outlined below]",
  "multimodal_cross_check": [boolean: true if uploaded files match verified web facts, false otherwise],
  "source_metadata": { 
    "types_analyzed": ["array of strings: e.g., 'text', 'image', 'pdf', 'url' based on what was provided"] 
  },
  "grounding_citations": [
    {"title": "string", "url": "string", "snippet": "string"}
  ],
  "media_literacy": { 
    "logical_fallacies": ["array of strings: any logical fallacies detected"], 
    "tone_analysis": "string" 
  }
}

### THE "ANALYSIS" FORMAT:
The "analysis" string MUST be formatted in Markdown and strictly use these four headings. 

**EXCEPTION FOR 'NOT_A_CLAIM':** If the verdict is "NOT_A_CLAIM", ignore the 4 headings below. Instead, provide a single, brief paragraph explaining why the input is subjective, a future prediction, or otherwise impossible to fact-check objectively.

**1. The Core Claim(s):**
[Provide a single, precise sentence PARAPHRASING what is being fact-checked. You MUST paraphrase in your own words. DO NOT quote the user's input verbatim under any circumstances to avoid triggering recitation filters.]

**2. Evidence Breakdown:**
[Use bullet points. State the raw facts found in the retrieved Google Search sources and uploaded files. Extract specific 'factual anchors'—such as numbers, dates, locations, or direct quotes—ONLY IF they are relevant to the claim. Do not force specific details if they do not apply. If the verdict is 'MIXTURE', you MUST explicitly list which specific parts of the input are true and which are false.]

**3. Context & Nuance:**
[Explain the background. Why might this claim be misleading? Is it a real photo taken out of context? Explain the "how" and "why" behind the verdict.]

**4. Red Flags & Discrepancies:**
[Use this section ONLY if there is conflicting information (e.g., an uploaded PDF contradicts the web, or two different news sites report different things). If there are no conflicts, write: "No major discrepancies found in the verified sources."]
"""
        from models import GroundingCitation, GroundingSupport, AnalysisResponse, ScannedSource
        
        # Configure the tool and system instructions using the new SDK syntax
        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.0,
            max_output_tokens=8192,
            tools=[{"google_search": {}}]
        )
        
        import asyncio
        max_attempts = 3
        
        # We wrap both the API call AND the JSON parsing in a retry loop
        for attempt in range(1, max_attempts + 1):
            response = None
            try:
                # Execute the call using genai_client
                response = genai_client.models.generate_content(
                    model="gemini-2.0-flash",
                    contents=gemini_parts,
                    config=config
                )
            except Exception as e:
                error_str = str(e)
                if "429" in error_str or "ResourceExhausted" in error_str or "Quota" in error_str:
                    logger.warning(f"Rate limit hit (429). Retrying... (Attempt {attempt}/{max_attempts})")
                    if attempt == 1:
                        await asyncio.sleep(2)
                        continue
                    elif attempt == 2:
                        await asyncio.sleep(4)
                        continue
                    else:
                        logger.error("Rate limit exhausted after 3 attempts.")
                        return AnalysisResponse(
                            verdict="RATE_LIMIT_ERROR",
                            confidence_score=0.0,
                            analysis="**1. System Status:**\nThe fact-checking system is currently experiencing high load. Please wait a moment before submitting another claim.",
                            grounding_citations=[]
                        )
                else:
                    raise e
                    
            # DEBUG: Print raw response to console for deep inspection
            print("\n[DEBUG] RAW RESPONSE METADATA:")
            if response.candidates:
                if response.candidates[0].grounding_metadata:
                    print(f"Grounding Metadata Attributes: {dir(response.candidates[0].grounding_metadata)}")
                    print(f"Grounding Metadata Dump: {response.candidates[0].grounding_metadata.model_dump_json(indent=2)}")
            
            # Forensic Audit: Write the entire grounding metadata object to a file for review
            import os
            base_dir = os.path.dirname(os.path.abspath(__file__))
            dump_path = os.path.join(base_dir, "grounding_metadata_dump.json")
            if response.candidates and response.candidates[0].grounding_metadata:
                # Convert the Pydantic model to a dict, then to a pretty string
                metadata_json = response.candidates[0].grounding_metadata.model_dump_json(indent=2)
                with open(dump_path, "w") as f:
                    f.write(metadata_json)
                print(f"\n[FORENSIC] Grounding metadata dumped to {dump_path}\n")
            else:
                with open(dump_path, "w") as f:
                    f.write('{"error": "NO GROUNDING METADATA FOUND"}')
                print("NO GROUNDING METADATA FOUND IN RESPONSE")

            try:
                response_text = response.text or ""
            except Exception:
                response_text = ""
                
            finish_reason = response.candidates[0].finish_reason if response.candidates else "UNKNOWN"
            print(f"[DEBUG] Finish Reason: {finish_reason}")
            print("\n" + "="*50)
            print(f"[DEBUG] Raw Model Text:\n{response_text}")
            print("="*50 + "\n")
            
            try:
                # Use our aggressive cleaner
                data = repair_and_parse_json(response_text)
                
                # Debug Dump: Model Output JSON
                output_dump_path = os.path.join(base_dir, "model_output_dump.json")
                with open(output_dump_path, "w") as f:
                    json.dump(data, f, indent=2)
                print(f"[FORENSIC] Model output dumped to {output_dump_path}")

                is_multimodal_verified = data.get("multimodal_cross_check", False)
                break # Success! Exit the loop
                
            except Exception as e:
                logger.error(f"[JSON PARSE ERROR on Attempt {attempt}] {e}")
                
                # FORENSIC DUMP: Save the exact string that broke the parser
                dump_path = os.path.join(base_dir, f"failed_json_dump_attempt_{attempt}.txt")
                with open(dump_path, "w", encoding="utf-8") as f:
                    f.write(f"ERROR: {str(e)}\n")
                    f.write("="*50 + "\n")
                    f.write(response_text or "NONE")
                print(f"[FORENSIC] Broken JSON dumped to {dump_path}")
                
                if attempt < max_attempts:
                    logger.warning("JSON severed or hallucinated. Retrying prompt.")
                    continue
                else:
                    # FALLBACK: If the LLM crashed, returned text, or got blocked by safety filters 3 times
                    logger.error("JSON parsing failed 3 times. Returning RECOVERING_FROM_HALLUCINATION fallback.")
                    
                    # We will return our new status code to UI
                    return AnalysisResponse(
                        verdict="RECOVERING_FROM_HALLUCINATION",
                        confidence_score=0.0,
                        analysis="**1. System Status:**\nVeriScan engines detected an anomaly in the AI response format. The system is re-validating the evidence block...",
                        grounding_citations=[]
                    )
        
        grounding_citations_fallback = []
        if response and response.candidates and response.candidates[0].grounding_metadata:
            chunks = getattr(response.candidates[0].grounding_metadata, 'grounding_chunks', []) or []
            if chunks:
                for i, chunk_obj in enumerate(chunks):
                    web_node = getattr(chunk_obj, 'web', None)
                    if web_node:
                        title = getattr(web_node, 'title', getattr(web_node, 'domain', "Unknown Source"))
                        uri = getattr(web_node, 'uri', "No source link available")
                        grounding_citations_fallback.append(GroundingCitation(
                            id=i + 1,
                            title=title,
                            url=uri,
                            snippet=title # Fallback snippet if LLM fails
                        ))

        if not data.get("grounding_citations") and grounding_citations_fallback:
             data["grounding_citations"] = [g.model_dump() for g in grounding_citations_fallback]
        
        # Prepare a URI to ID map from grounding chips
        uri_to_id = {}
        if response and response.candidates and response.candidates[0].grounding_metadata:
            chunks = getattr(response.candidates[0].grounding_metadata, 'grounding_chunks', []) or []
            for i, chunk_obj in enumerate(chunks):
                web_node = getattr(chunk_obj, 'web', None)
                if web_node:
                    uri = getattr(web_node, 'uri', "")
                    if uri:
                        uri_to_id[normalize_url(uri)] = i + 1

        # Final Sanitization: Attach correct IDs to citations
        sanitized_citations = []
        for gc in data.get("grounding_citations", []):
            if isinstance(gc, dict):
                matched_file = None
                for fname in file_names:
                    if fname in (gc.get("title") or "") or fname in (gc.get("snippet") or ""):
                        matched_file = fname
                        break
                
                gc["source_file"] = matched_file
                if not gc.get("url") or gc.get("url") == "No source link available":
                    if matched_file:
                        gc["url"] = f"file://{matched_file}"
                    else:
                        gc["url"] = "No source link available"
                
                if not gc.get("title"):
                    gc["title"] = matched_file or "Untitled Source"
                
                # Assign ID based on URL match with master chunks
                norm_url = normalize_url(gc.get("url", ""))
                gc["id"] = uri_to_id.get(norm_url, 0) # 0 if not found in master chunks
                
                if gc.get("snippet"):
                    gc["snippet"] = sanitize_grounding_text(gc["snippet"])
                
                url_str = (gc.get("url") or "").lower()
                snippet_str = (gc.get("snippet") or "").lower()
                status = "live"
                social_domains = ["instagram.com", "facebook.com", "twitter.com", "x.com", "tiktok.com", "reddit.com"]
                if any(domain in url_str for domain in social_domains):
                    status = "restricted"
                elif not gc.get("snippet") or "failed to fetch" in snippet_str or "could not be reached" in snippet_str:
                    status = "dead"
                
                gc["status"] = status
                sanitized_citations.append(gc)
            else:
                sanitized_citations.append(gc)
        data["grounding_citations"] = sanitized_citations

        # --- Populate Scanned Sources ---
        scanned_sources = []
        if response and response.candidates and response.candidates[0].grounding_metadata:
            chunks = getattr(response.candidates[0].grounding_metadata, 'grounding_chunks', []) or []
            cited_urls = {normalize_url(gc.get("url")) for gc in sanitized_citations if gc.get("url")}
            
            seen_urls = set()
            for i, chunk_obj in enumerate(chunks):
                web_node = getattr(chunk_obj, 'web', None)
                if web_node:
                    title = getattr(web_node, 'title', "Untitled Source")
                    uri = getattr(web_node, 'uri', "")
                    norm_uri = normalize_url(uri)
                    if not uri or norm_uri in seen_urls:
                        continue
                    
                    seen_urls.add(norm_uri)
                    scanned_sources.append(ScannedSource(
                        id=i + 1, # Unified Rule: ID = chunk_index + 1
                        title=title,
                        url=uri,
                        is_cited=norm_uri in cited_urls
                    ).model_dump())
            
            # Add fallback scanned sources for referenced but non-web chunks (files)
            for i, chunk_obj in enumerate(chunks):
                if not hasattr(chunk_obj, 'web') or not chunk_obj.web:
                    # This might be a file grounding. Try to find a matching citation by ID.
                    chunk_id = i + 1
                    citation = next((c for c in sanitized_citations if c.get("id") == chunk_id), None)
                    if citation and citation.get("source_file"):
                        filename = citation["source_file"]
                        uri = f"file://{filename}"
                        norm_uri = normalize_url(uri)
                        if norm_uri not in seen_urls:
                            seen_urls.add(norm_uri)
                            scanned_sources.append(ScannedSource(
                                id=chunk_id,
                                title=filename,
                                url=uri,
                                is_cited=True
                            ).model_dump())
        
        data["scanned_sources"] = scanned_sources

        service_sources = []
        final_citations = data.get("grounding_citations", [])
        for gc in final_citations:
            url_val = gc.get("url") if isinstance(gc, dict) else getattr(gc, "url", "")
            title_val = gc.get("title") if isinstance(gc, dict) else getattr(gc, "title", "")
            snippet_val = gc.get("snippet") if isinstance(gc, dict) else getattr(gc, "snippet", "")
            
            status_val = gc.get("status", "live") if isinstance(gc, dict) else getattr(gc, "status", "live")
            
            service_sources.append({
                "uri": url_val or "No source link available",
                "title": title_val or "Untitled Source",
                "text": snippet_val or title_val,
                "status": status_val
            })
        
        
        grounding_service = get_grounding_service()
        grounding_result = grounding_service.process(data.get("analysis", ""), service_sources)
        grounding_supports_heuristic = grounding_result.get("groundingSupports", [])
        
        # Phase 2: Math Engine Integration
        try:
            from logic import calculate_reliability
            # Determine grounding sources for math engine. 
            # PRIORITY: If API returned supports directly, use them (they have real confidence scores).
            # FALLBACK: Use heuristic keyword-mapped supports.
            api_supports = []
            if response and response.candidates and hasattr(response.candidates[0].grounding_metadata, 'grounding_supports'):
                raw_api_supports = response.candidates[0].grounding_metadata.grounding_supports or []
                # Convert Pydantic models to camelCase dicts for AnalysisResponse consistency
                for sup in raw_api_supports:
                    sup_dict = sup.model_dump()
                    segment_obj = sup_dict.get("segment") or {}
                    raw_seg_text = segment_obj.get("text", "")
                    
                    # 1. Robust Unescaping
                    try:
                        # Ensures \\n becomes \n and other escaped chars are handled
                        unescaped_text = raw_seg_text.encode('utf-8').decode('unicode_escape')
                    except Exception:
                        unescaped_text = raw_seg_text.replace('\\n', '\n').replace('\\"', '"')

                    # 2. Segment Trimming (Markdown Headers & Bullet Points)
                    # Regex to find leading **Section Header:** or * Bullet points
                    # and capture the remaining text.
                    trim_match = re.match(r'^(\s*(?:\*\*[^*]+\*\*:\s*|\*+\s*))(.*)', unescaped_text, re.DOTALL)
                    
                    final_seg_text = unescaped_text
                    start_offset = 0
                    
                    if trim_match:
                        prefix = trim_match.group(1)
                        final_seg_text = trim_match.group(2)
                        start_offset = len(prefix)
                    
                    standardized = {
                        "segment": {
                            "startIndex": (segment_obj.get("start_index") or 0) + start_offset,
                            "endIndex": segment_obj.get("end_index") or 0,
                            "text": final_seg_text
                        },
                        "groundingChunkIndices": sup_dict.get("grounding_chunk_indices") or [],
                        "confidenceScores": sup_dict.get("confidence_scores") or []
                    }
                    api_supports.append(standardized)
            
            final_supports = api_supports if api_supports else grounding_supports_heuristic
            data["grounding_supports"] = final_supports
            
            # Grounding chunks (Sources)
            grounding_chunks = []
            if response and response.candidates and response.candidates[0].grounding_metadata.grounding_chunks:
                grounding_chunks = response.candidates[0].grounding_metadata.grounding_chunks
            
            import sys
            sys.stdout.flush()
            
            reliability_metrics = calculate_reliability(
                final_supports, 
                grounding_chunks, 
                data.get("grounding_citations", []),
                is_multimodal_verified,
                ai_confidence=float(data.get("confidence_score", 0.0))
            )
            data["reliability_metrics"] = reliability_metrics
            
            # Map VERDICT label back explicitly if not present or for engine-driven overrides if specifically requested
            # However, per user request, we now let the model provide the top-level verdict/score
            # and keep the reliability engine metrics separate.
            # Fallback: Default to UNVERIFIABLE if model fails to provide verdict
            if "verdict" not in data or not data["verdict"]:
                data["verdict"] = "UNVERIFIABLE"
            else:
                # Ensure normalization to standard strings
                v = str(data["verdict"]).upper().strip()
                valid_tiers = ["TRUE", "MOSTLY_TRUE", "MIXTURE", "MISLEADING", "MOSTLY_FALSE", "FALSE", "UNVERIFIABLE", "NOT_A_CLAIM"]
                if v not in valid_tiers:
                    # Simple heuristic mapping for minor typos
                    if "TRUE" in v: data["verdict"] = "TRUE"
                    elif "FALSE" in v: data["verdict"] = "FALSE"
                    else: data["verdict"] = "UNVERIFIABLE"
                else:
                    data["verdict"] = v
                 
        except Exception as e:
            logger.error(f"Error calculating reliability: {e}")
            import traceback
            traceback.print_exc()

        raw_analysis = data.get("analysis", "") or "**1. The Core Claim(s):**\nThe data could not be parsed.\n\n**2. Evidence Breakdown:**\n* The AI returned malformed data or was blocked by safety filters."
        
        # The model sometimes returns literal '\n' and '\"' strings instead of actual characters
        # due to its internal interpretation of JSON safety. We unescape them here.
        if isinstance(raw_analysis, str):
            sanitized_analysis = raw_analysis.replace('\\n', '\n').replace('\\"', '"')
        else:
            sanitized_analysis = str(raw_analysis)

        # Phase 3: Fuzzy Anchor Re-indexing
        # After citation brackets are injected (in standardize_analysis or similar),
        # we must find the strings again to ensure UI highlights are accurate.
        clean_analysis = normalize_for_search(sanitized_analysis)
        for support in data.get("grounding_supports", []):
            segment = support.get("segment", {})
            anchor_text = segment.get("text", "")
            if not anchor_text:
                continue
            
            clean_anchor = normalize_for_search(anchor_text)
            
            # 1. Try Exact Match in normalized text
            new_start = clean_analysis.find(clean_anchor)
            
            # 2. Try Partial Match (Fingerprint) if exact fails
            if new_start == -1:
                # Use first 20 chars as unique fingerprint to avoid bracket collisions
                fingerprint = clean_anchor[:min(len(clean_anchor), 20)]
                if len(fingerprint) >= 5: # Ensure fingerprint is meaningful
                    new_start = clean_analysis.find(fingerprint)
            
            if new_start != -1:
                segment["startIndex"] = new_start
                segment["endIndex"] = new_start + len(anchor_text) # Use original length for indexing

        final_response = AnalysisResponse(
            verdict=data.get("verdict", "UNVERIFIABLE"),
            confidence_score=data.get("confidence_score", 0.0),
            analysis=sanitized_analysis,
            multimodal_cross_check=data.get("multimodal_cross_check", False),
            reliability_metrics=data.get("reliability_metrics"),
            grounding_citations=data.get("grounding_citations", []),
            scanned_sources=data.get("scanned_sources", []),
            grounding_supports=data.get("grounding_supports", [])
        )

        return final_response

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
            verdict="UNVERIFIABLE",
            confidence_score=0.0,
            analysis=f"System Error: {str(e)}",
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
                    gemini_parts.append(types.Part.from_bytes(**part_args))
                    prompt_content += f"[Image Attached: {file.filename} ({mime_type})]\n"
                elif mime_type == "application/pdf":
                    gemini_parts.append(types.Part.from_bytes(**part_args))
                    prompt_content += f"[PDF Document Attached (Medium Resolution): {file.filename}]\n"
                else:
                    logger.warning(f"Unsupported file type: {mime_type}")

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
            'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        })

    # --- Community routes: forward to FastAPI app ---
    # Firebase Hosting rewrites /community/** to this Cloud Function.
    # Detect community paths and handle them via the FastAPI ASGI app.
    req_path = req.path or ''
    if '/community' in req_path:
        import asyncio

        async def _handle_community():
            # Build a minimal ASGI scope from the Cloud Function request
            body = req.get_data()
            headers = [(k.lower().encode(), v.encode()) for k, v in req.headers.items()]
            
            # Strip everything before /community so FastAPI routing works
            community_path = '/community' + req_path.split('/community', 1)[-1]
            
            scope = {
                'type': 'http',
                'method': req.method,
                'path': community_path,
                'query_string': req.query_string,
                'headers': headers,
                'root_path': '',
            }

            response_body = []
            response_status = [200]
            response_headers = [{}]

            async def receive():
                return {'type': 'http.request', 'body': body, 'more_body': False}

            async def send(message):
                if message['type'] == 'http.response.start':
                    response_status[0] = message['status']
                    response_headers[0] = {
                        k.decode(): v.decode() 
                        for k, v in message.get('headers', [])
                    }
                elif message['type'] == 'http.response.body':
                    response_body.append(message.get('body', b''))

            await app(scope, receive, send)
            return (
                b''.join(response_body),
                response_status[0],
                response_headers[0],
            )

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            body_bytes, status_code, resp_headers = loop.run_until_complete(_handle_community())
            resp_headers['Access-Control-Allow-Origin'] = '*'
            return https_fn.Response(
                body_bytes,
                status=status_code,
                headers=resp_headers,
                mimetype=resp_headers.get('content-type', 'application/json'),
            )
        except Exception as e:
            logger.error(f"Community route error: {e}")
            return https_fn.Response(
                json.dumps({"error": str(e)}),
                status=500,
                mimetype='application/json',
                headers={'Access-Control-Allow-Origin': '*'},
            )
        finally:
            loop.close()

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
                        gemini_parts.append(types.Part.from_bytes(**part_args))
                        prompt_content += f"[Image Attached: {f.filename}]\n"
                    elif mime_type == "application/pdf":
                        gemini_parts.append(types.Part.from_bytes(**part_args))
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