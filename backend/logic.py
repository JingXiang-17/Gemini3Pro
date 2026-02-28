import json
import os
import urllib.parse

# Load verified signatories at module level
VERIFIED_DOMAINS = set()
try:
    data_dir = os.path.join(os.path.dirname(__file__), 'data')
    verified_path = os.path.join(data_dir, 'verified_domains.json')
    if os.path.exists(verified_path):
        with open(verified_path, 'r', encoding='utf-8') as f:
            VERIFIED_DOMAINS = set(json.load(f))
except Exception as e:
    print(f"Warning: Could not load verified domains: {e}")

# Helper for enforcing strict domain checks
def normalize_domain_name(domain: str) -> str:
    if not domain:
        return ""
    domain = urllib.parse.unquote(domain).strip().lower()
    if domain.startswith("http://") or domain.startswith("https://"):
        try:
            domain = urllib.parse.urlparse(domain).netloc
        except Exception:
            pass
    if domain.startswith("www."):
        domain = domain[4:]
    return domain

# Domain Authority Multipliers (from V2 logic or similar heuristics)
def get_authority_multiplier(domain: str) -> float:
    domain = normalize_domain_name(domain)
    
    # NEW: Tier 1 override for Verified Fact-Checkers
    is_verified_signatory = domain in VERIFIED_DOMAINS
    print(f"DEBUG: Domain {domain} verified status: {is_verified_signatory}")
    if is_verified_signatory:
        return 1.0
        
    if domain.endswith('.gov') or domain.endswith('.edu') or domain.endswith('.int'):
        return 1.0  # Highest authority
    if domain.endswith('.org') or domain in ['bbc.com', 'bbc.co.uk', 'reuters.com', 'apnews.com', 'npr.org']:
        return 0.9  # High authority orgs/news
    if domain in ['wikipedia.org', 'en.wikipedia.org']:
        return 0.8  # Commendable but crowd-sourced
    
    social_domains = ['twitter.com', 'x.com', 'facebook.com', 'instagram.com', 'tiktok.com', 'reddit.com', 'youtube.com']
    if any(sd in domain for sd in social_domains):
        return 0.4  # Social media / UGC
    
    # Check for file extensions (indicates an uploaded file used as ground truth)
    if any(domain.lower().endswith(ext) for ext in ['.pdf', '.jpg', '.jpeg', '.png', '.txt', '.docx']):
        return 1.0 # Direct user-provided evidence
        
    return 0.7  # Default for unknown .com/.net/...

def extract_domain(url: str) -> str:
    if not url:
        return "unknown"
    try:
        parsed_uri = urllib.parse.urlparse(url)
        domain = parsed_uri.netloc
        
        # Handle Google Search Redirects
        if domain in ["www.google.com", "google.com"] and "/url" in parsed_uri.path:
            query_params = urllib.parse.parse_qs(parsed_uri.query)
            if 'q' in query_params:
                return extract_domain(query_params['q'][0])
            elif 'url' in query_params:
                return extract_domain(query_params['url'][0])
                
        return domain
    except Exception:
        return "unknown"

def calculate_reliability(grounding_supports: list, grounding_chunks: list, grounding_citations: list, is_multimodal_verified: bool, ai_confidence: float = 0.0) -> dict:
    """
    Implements the V3 Strongest Link Math Engine.
    """
    # EARLY EXIT: If there are no sources used, return a safe zeroed payload
    if not grounding_supports:
        return {
            "reliability_score": 0.0,
            "ai_confidence": ai_confidence,
            "base_grounding": 0.0,
            "consistency_bonus": 0.0,
            "multimodal_bonus": 0.0,
            "verdict_label": "Unverified / No Data",
            "explanation": "No reliable search results were found to verify this claim.",
            "segments": [],
            "unused_sources": [] # Ensure frontend doesn't crash trying to map this
        }

    segment_audits = []
    used_domains = set()
    used_chunk_indices = set()

    # Pre-compute URI to Source Index mapping from Citations
    uri_to_source_index = {}
    snippet_map = {}
    for idx, citation in enumerate(grounding_citations):
        # Handle dict or Pydantic object
        uri = citation.get('url', '') if isinstance(citation, dict) else getattr(citation, 'url', '')
        snippet = citation.get('snippet', 'Content unavailable.') if isinstance(citation, dict) else getattr(citation, 'snippet', 'Content unavailable.')
        if uri:
            uri_to_source_index[uri] = idx
            snippet_map[uri] = snippet

    # Define a helper for robust field extraction (snake_case vs camelCase)
    def github_get(obj, *fields):
        for f in fields:
            if hasattr(obj, f):
                return getattr(obj, f)
            if isinstance(obj, dict) and f in obj:
                return obj[f]
        return None

    print("\n" + "="*50)
    print("[RAW_METADATA_AUDIT] Grounding Supports Structure")
    for i, support in enumerate(grounding_supports): # Audit all segments
        segment = github_get(support, 'segment') or {}
        segment_text = github_get(segment, 'text') or 'Unknown segment text'
        indices = github_get(support, 'grounding_chunk_indices', 'groundingChunkIndices') or []
        conf_scores = github_get(support, 'confidence_scores', 'confidenceScores') or 'NOT FOUND'
        print(f"--- Segment {i} ---")
        print(f"  Text: '{segment_text[:50]}...'")
        print(f"  Chunk Indices: {indices}")
        print(f"  Raw Confidence Scores: {conf_scores}")
    print("="*50 + "\n")

    for seg_idx, support in enumerate(grounding_supports):
        # Determine attributes robustly
        segment = github_get(support, 'segment') or {}
        segment_text = github_get(segment, 'text') or 'Unknown segment text'
        
        indices = github_get(support, 'grounding_chunk_indices', 'groundingChunkIndices') or []
        conf_scores = github_get(support, 'confidence_scores', 'confidenceScores') or []
        
        evaluated_sources = []
        best_score = 0.0
        best_domain = "unknown"

        for i, chunk_idx in enumerate(indices):
            if chunk_idx < 0 or chunk_idx >= len(grounding_chunks):
                continue
                
            chunk = grounding_chunks[chunk_idx]
            
            # Handle Vertex AI chunk object vs local dict representation
            if hasattr(chunk, 'web') and chunk.web:
                raw_domain = getattr(chunk.web, 'domain', '') or getattr(chunk.web, 'title', 'unknown')
                raw_uri = getattr(chunk.web, 'uri', '')
                raw_title = getattr(chunk.web, 'title', 'No snippet available.')
            else:
                 raw_domain = chunk.get('domain', '') or chunk.get('title', 'unknown') if isinstance(chunk, dict) else 'unknown'
                 raw_uri = chunk.get('uri', '') if isinstance(chunk, dict) else ''
                 raw_title = chunk.get('title', 'No snippet available.') if isinstance(chunk, dict) else 'No snippet available.'
            
            source_index = uri_to_source_index.get(raw_uri, -1)
            quote_text = snippet_map.get(raw_uri, raw_title)
            
            used_chunk_indices.add(chunk_idx)
            
            if raw_domain and raw_domain != "unknown":
                used_domains.add(raw_domain)

            auth = get_authority_multiplier(raw_domain)
            
            # Default to 1.0 for files if API confidence is missing (it's user context)
            conf = conf_scores[i] if i < len(conf_scores) else (1.0 if raw_uri.startswith("file://") else 0.0)
            chunk_score = conf * auth
            
            clean_domain_for_check = normalize_domain_name(raw_domain)
            is_verified = clean_domain_for_check in VERIFIED_DOMAINS
            
            evaluated_sources.append({
                "id": chunk_idx + 1, # 1-indexed source ID
                "chunk_index": chunk_idx,
                "source_index": source_index,
                "domain": raw_domain,
                "score": chunk_score,
                "quote_text": quote_text,
                "confidence": conf,
                "authority": auth,
                "is_verified": is_verified
            })
            
            print(f"[DEBUG_EVAL] Seg {seg_idx} | Chunk {chunk_idx} | DocIdx {source_index} | Domain: {raw_domain} | Conf: {conf:.2f} | Auth: {auth:.2f} | Score: {chunk_score:.2f}")
            
            if chunk_score > best_score:
                best_score = chunk_score
                best_domain = raw_domain

        # Sort sources by score descending
        evaluated_sources.sort(key=lambda x: x['score'], reverse=True)

        segment_audits.append({
            "text": segment_text,
            "top_source_domain": best_domain,
            "top_source_score": best_score,
            "sources": evaluated_sources
        })

    # Global Average Segment Score
    if segment_audits:
        base_grounding = sum(audit["top_source_score"] for audit in segment_audits) / len(segment_audits)
    else:
        base_grounding = 0.0

    # Collect unused sources
    unused_sources = []
    seen_unused_domains = set()
    
    for chunk_idx, chunk in enumerate(grounding_chunks):
        if chunk_idx not in used_chunk_indices:
            if hasattr(chunk, 'web') and chunk.web:
                domain = getattr(chunk.web, 'domain', None) or extract_domain(getattr(chunk.web, 'uri', '')) or getattr(chunk.web, 'title', 'unknown')
                title = getattr(chunk.web, 'title', 'unknown')
            else:
                domain = chunk.get('domain', None) or extract_domain(chunk.get('uri', '')) or chunk.get('title', 'unknown') if isinstance(chunk, dict) else 'unknown'
                title = chunk.get('title', 'unknown') if isinstance(chunk, dict) else 'unknown'
                
            if domain and domain != "unknown" and domain not in used_domains and domain not in seen_unused_domains:
                unused_sources.append({
                    "domain": domain,
                    "title": title
                })
                seen_unused_domains.add(domain)

    # Additive Bonuses
    consistency_bonus = 0.05 if len(used_domains) > 1 else 0.0
    multimodal_bonus = 0.05 if is_multimodal_verified else 0.0

    final_score = min(1.0, base_grounding + consistency_bonus + multimodal_bonus)

    # Verdict Labeling
    if final_score > 0.85:
        verdict_label = "High (Verified Institutional)"
    elif final_score > 0.70:
        verdict_label = "Medium-High (Verified News)"
    elif final_score > 0.50:
        verdict_label = "Medium (Mixed/Uncertain)"
    else:
        verdict_label = "Low (Unverified)"
        
    explanation = f"Base grounding evaluated at {base_grounding:.2f} across {len(segment_audits)} segments. "
    if consistency_bonus > 0:
        explanation += f"Consistency bonus (+0.05) applied for {len(used_domains)} unique domains. "
    if multimodal_bonus > 0:
         explanation += "Multimodal cross-check bonus (+0.05) applied."

    print("\n[FORENSIC_AUDIT] Segment Breakdown:")
    for idx, audit in enumerate(segment_audits):
         print(f"[FORENSIC_AUDIT] Segment {idx} | Best Source: {audit['top_source_domain']} | Score: {audit['top_source_score']:.2f}")
    
    print(f"[FORENSIC_AUDIT] Final Base: {base_grounding:.2f} | Consistency: {consistency_bonus:.2f} | Multimodal: {multimodal_bonus:.2f}")
    print(f"[FORENSIC_AUDIT] Final Reliability Score: {final_score:.2f} ({verdict_label})\n")

    return {
        "reliability_score": final_score,
        "ai_confidence": ai_confidence,
        "base_grounding": base_grounding,
        "consistency_bonus": consistency_bonus,
        "multimodal_bonus": multimodal_bonus,
        "verdict_label": verdict_label,
        "explanation": explanation,
        "segments": segment_audits,
        "unused_sources": unused_sources
    }
