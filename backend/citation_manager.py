import logging
import re
from typing import List, Dict, Any, Tuple
from models import Source

logger = logging.getLogger(__name__)

class CitationManager:
    """
    Manages the injection of citation tags into the analysis text
    and constructs the list of Source objects from grounding metadata.
    """

    def process_grounding(self, target_text: str, grounding_metadata: Any, raw_response_text: str = None) -> Tuple[str, List[Source]]:
        """
        Processes the grounding metadata to inject citations into the target_text.
        
        Args:
            target_text: The text where citations should be injected (e.g. from JSON).
            grounding_metadata: The metadata object from Vertex AI.
            raw_response_text: The full raw text response from Vertex AI (used to extract segment text).
            
        Returns:
            Tuple[str, List[Source]]: The modified text with [x] tags and the list of sources.
        """
        if not grounding_metadata:
            return target_text, []

        supports = getattr(grounding_metadata, 'grounding_supports', [])
        chunks = getattr(grounding_metadata, 'grounding_chunks', [])
        web_search_queries = getattr(grounding_metadata, 'web_search_queries', [])
        
        if not supports:
            return target_text, []

        from urllib.parse import urlparse

        sources: List[Source] = []
        chunk_index_to_source_id: Dict[int, str] = {}
        
        # Flatten supports to a list of injection points
        segments_to_inject = []
        
        for support in supports:
            segment = support.segment
            
            # STITCHER LOGIC:
            # We need to find where this segment is in the TARGET text.
            # The indices in `segment` correspond to `raw_response_text`.
            
            segment_text = ""
            if hasattr(segment, 'text') and segment.text:
                segment_text = segment.text
            elif raw_response_text:
                # Fallback: Extract from raw response
                if segment.end_index <= len(raw_response_text):
                    segment_text = raw_response_text[segment.start_index:segment.end_index]
            
            if not segment_text:
                logger.warning("CITATION: Could not resolve segment text. Skipping.")
                continue
                
            # Clean up segment text for fuzzy matching (remove extra spaces)
            clean_segment = segment_text.strip()
            if not clean_segment:
                continue

            # Find this text in the target_text
            # Note: This is a simple find. For production, consider fuzzy matching or normalizing whitespace.
            start_in_target = target_text.find(clean_segment)
            
            if start_in_target == -1:
                # Fallback: Keyword/Fuzzy Match
                # If exact sentence isn't found, try to find a sentence that shares significant keywords.
                # This handles cases where Gemini slightly rephrased the summary in JSON.
                
                # 1. Split segment into keywords (long words > 4 chars)
                keywords = [w for w in clean_segment.split() if len(w) > 4]
                if not keywords:
                     keywords = clean_segment.split() # Fallback to all words if short
                
                best_match_idx = -1
                max_score = 0
                
                # Simple sliding window or sentence split could work. 
                # Let's search for the first occurrence of the most significant chunk of keywords?
                # A safer heuristic: Find the first 3 consecutive keywords?
                
                if len(keywords) >= 3:
                    trigram = " ".join(keywords[:3])
                    start_in_target = target_text.find(trigram)
                
                if start_in_target == -1:
                     logger.warning(f"CITATION: Segment text not found in target (even with fallback). Segment: '{clean_segment[:30]}...'")
                     continue
            
            end_in_target = start_in_target + len(clean_segment)
            
            # Clamp end index if fuzzy match went weird (though find returns exact start)
            if end_in_target > len(target_text): 
                end_in_target = len(target_text)
            
            segments_to_inject.append({
                'start': start_in_target,
                'end': end_in_target,
                'chunk_indices': support.grounding_chunk_indices
            })
            
        # Sort by end index descending to safely inject into string
        segments_to_inject.sort(key=lambda x: x['end'], reverse=True)
        
        modified_text = target_text
        
        for segment in segments_to_inject:
            end_index = segment['end']
            chunk_indices = segment['chunk_indices']
            
            citation_tags = []
            
            for chunk_idx in chunk_indices:
                # Ensure we track sources uniquely
                if chunk_idx not in chunk_index_to_source_id:
                     # ... (rest of source creation is largely the same, just ensuring we don't duplicate logic if not needed)
                     pass

                # START SOURCE CREATION (Copied/Refined from above to ensure scope)
                if chunk_idx not in chunk_index_to_source_id:
                    new_id = str(len(sources) + 1)
                    chunk_index_to_source_id[chunk_idx] = new_id
                    
                    # Store the referenced text segment
                    cited_segment_text = target_text[segment['start']:segment['end']]
                    if len(cited_segment_text) < 5: # If fuzzy match failed to get text, use original
                         cited_segment_text = clean_segment

                    if chunks and chunk_idx < len(chunks):
                        chunk = chunks[chunk_idx]
                        web = getattr(chunk, 'web', None)
                        if web:
                            url = getattr(web, 'uri', '')
                            title = getattr(web, 'title', 'Unknown Source')
                        else:
                            url = ''
                            title = 'Unknown Source'
                            
                        domain = urlparse(url).netloc if url else "unknown"
                        source_context = f"{title} ({domain})"
                        
                        if hasattr(chunk, 'retrieved_context'):
                             ctx = getattr(chunk, 'retrieved_context')
                             if ctx: 
                                 source_context = str(ctx)

                        favicon_url = f"https://www.google.com/s2/favicons?domain={domain}&sz=64" if url else None
                    
                        sources.append(Source(
                            id=new_id,
                            title=title,
                            url=url,
                            cited_segment=cited_segment_text,
                            source_context=source_context,
                            favicon_url=favicon_url
                        ))
                    else:
                         sources.append(Source(id=new_id, title="Reference", url="", cited_segment=cited_segment_text, source_context="Offline reference", favicon_url=None))
                
                citation_tags.append(f"[{chunk_index_to_source_id[chunk_idx]}]")
            
            if citation_tags:
                tag_string = " " + "".join(citation_tags)
                # Check if we are inserting right after a punctuation or space?
                # Just insert at end of segment matching in target.
                modified_text = modified_text[:end_index] + tag_string + modified_text[end_index:]
                
        return modified_text, sources
