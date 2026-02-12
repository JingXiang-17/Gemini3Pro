import re
import logging
from typing import List, Dict, Any, Tuple

# Configure logging to go to console as requested
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("GroundingService")

class GroundingService:
    """
    A service to generate Vertex AI-style GroundingMetadata from raw text and sources.
    """

    def _get_utf16_length(self, s: str) -> int:
        """
        Calculates the length of the string in UTF-16 code units.
        This is crucial for compatibility with Flutter/Dart indexing.
        """
        return len(s.encode('utf-16-le')) // 2

    def _segment_text(self, text: str) -> List[Dict[str, Any]]:
        """
        Splits text into segments (sentences/claims).
        Returns a list of dicts with 'text', 'start', 'end' (UTF-16 offsets).
        """
        segments = []
        # Simple regex for sentence splitting. 
        # Captures punctuation to keep offsets correct, but we want the inner text for mapping.
        # This splits by standard sentence terminators.
        # We assume the analysis text is relatively clean.
        
        # Determine offsets iteratively
        current_utf16_idx = 0
        
        # Split by sentence endings (. ! ?) follow by space or end of string
        # We stick to a simple split to avoid complex NLP dependency for now
        # re.split includes the delimiters if captured in (), but we just want to find spans.
        
        # Using finditer is better to get spans
        # This regex matches a sentence: non-terminators followed by a terminator or end of string
        sentence_pattern = re.compile(r'[^.!?]+[.!?]*')
        
        matches = list(sentence_pattern.finditer(text))
        
        # If no punctuation, treat whole text as one segment
        if not matches and text.strip():
             segments.append({
                "text": text,
                "startIndex": 0,
                "endIndex": self._get_utf16_length(text)
            })
             # Log raw length here for the first segment logic? No, do it globally.
             return segments

        for match in matches:
            span_text = match.group()
            if not span_text.strip():
                continue
                
            # Calculate UTF-16 offsets relative to the start of the string
            # We can't just use match.start() because preceeding chars might be multi-byte.
            preceding_text = text[:match.start()]
            start_idx = self._get_utf16_length(preceding_text)
            
            segment_len = self._get_utf16_length(span_text)
            end_idx = start_idx + segment_len
            
            segments.append({
                "text": span_text,
                "startIndex": start_idx,
                "endIndex": end_idx
            })
            
            logger.info(f"[DEBUG] Segment Found: \"{span_text.strip()[:30]}...\" at [{start_idx}:{end_idx}]")

        return segments

    def _map_segments_to_sources(self, segments: List[Dict[str, Any]], sources: List[Dict[str, str]]) -> Tuple[List[Dict[str, Any]], List[int]]:
        """
        Maps each segment to one or more source candidates based on keyword overlap.
        """
        supports = []
        all_referenced_indices = []

        # Pre-process sources into sets of keywords for faster checking
        source_keywords = []
        for idx, src in enumerate(sources):
            # simple tokenization: lowercase, split by space, remove short words
            text = (src.get('text') or src.get('title') or "").lower()
            tokens = set(w for w in re.split(r'\W+', text) if len(w) > 2)
            source_keywords.append(tokens)
            logger.info(f"[DEBUG] Source {idx} Tokens: {tokens}")

        for segment in segments:
            seg_text = segment['text']
            seg_tokens = set(w for w in re.split(r'\W+', seg_text.lower()) if len(w) > 2)
            
            if not seg_tokens:
                continue
            
            logger.info(f"[DEBUG] Segment Tokens: {seg_tokens}")

            mapped_indices = []
            
            # Check against each source
            for idx, src_tokens in enumerate(source_keywords):
                if not src_tokens:
                    continue
                
                # Jaccard/Overlap similarity
                intersection = seg_tokens.intersection(src_tokens)
                
                # Dynamic Threshold:
                # If source is just a title (short), require less overlap (e.g. 1 keyword like "Mars")
                is_short_source = len(src_tokens) < 5
                
                # If short source, 1 strong keyword is enough.
                # If long source, want at least 2 or significant ratio.
                if is_short_source:
                    match = len(intersection) >= 1
                else:
                    match = len(intersection) >= 2 or (len(intersection) / len(seg_tokens) > 0.3)

                if match:
                    mapped_indices.append(idx)
            
            if mapped_indices:
                logger.info(f"[DEBUG] Mapping Segment to Chunk Indices: {mapped_indices}")
                
                # Check for out of bounds (Integrity Check)
                valid_indices = []
                for idx in mapped_indices:
                    if 0 <= idx < len(sources):
                        valid_indices.append(idx)
                    else:
                        logger.error(f"[CRITICAL] Index {idx} out of bounds! Excluding.")
                
                if valid_indices:
                    supports.append({
                        "segment": {
                            "startIndex": segment['startIndex'],
                            "endIndex": segment['endIndex'],
                            "text": segment['text']
                        },
                        "groundingChunkIndices": valid_indices,
                        "confidenceScores": [0.9] * len(valid_indices) # Mock confidence
                    })
                    all_referenced_indices.extend(valid_indices)

        return supports, all_referenced_indices

    def process(self, analysis_text: str, sources: List[Dict[str, str]]) -> Dict[str, Any]:
        """
        Main entry point.
        """
        
        # 1. Log Raw Analysis Length
        utf16_len = self._get_utf16_length(analysis_text)
        logger.info(f"[DEBUG] Raw Analysis Length: {utf16_len}")
        logger.info(f"[DEBUG] Processing with {len(sources)} sources.")
        if sources:
             logger.info(f"[DEBUG] First Source Text: {sources[0].get('text', '')[:50]}...")
        else:
             logger.info(f"[DEBUG] Sources list is empty!")

        # 2. Segment
        segments = self._segment_text(analysis_text)
        
        # 3. Map
        supports, all_indices = self._map_segments_to_sources(segments, sources)

        # 4. Construct Payload
        grounding_chunks = []
        for src in sources:
             grounding_chunks.append({
                 "uri": src.get('uri', ''),
                 "title": src.get('title', 'Unknown'),
                 "retrievedContext": {"uri": src.get('uri'), "title": src.get('title')} 
             })

        payload = {
            "webSearchQueries": [],
            "groundingChunks": grounding_chunks,
            "groundingSupports": supports,
            "groundingAttributions": []
        }

        # 5. Validation Check
        is_valid = True
        chunk_count = len(grounding_chunks)
        for idx in all_indices:
            if idx < 0 or idx >= chunk_count:
                is_valid = False
                break
        
        logger.info(f"[DEBUG] JSON Payload Validated: {is_valid}")
        
        return payload

if __name__ == "__main__":
    # Quick manual test if run directly
    service = GroundingService()
    text = "The sky is blue. Mars is red."
    sources = [
        {"text": "The atmosphere scatters blue light making the sky appear blue.", "title": "Atmosphere"},
        {"text": "Iron oxide dust makes Mars look red.", "title": "Mars"}
    ]
    result = service.process(text, sources)
    import json
    print(json.dumps(result, indent=2))
