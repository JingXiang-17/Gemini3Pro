from typing import List, Optional, Literal
from pydantic import BaseModel, Field

class SourceMetadata(BaseModel):
    type: Literal["text", "url", "image"]
    provided_url: Optional[str] = None
    page_title: Optional[str] = None

class GroundingCitation(BaseModel):
    title: str
    url: str
    snippet: str

class MediaLiteracy(BaseModel):
    logical_fallacies: List[str]
    tone_analysis: str

class AnalysisResponse(BaseModel):
    verdict: Literal["REAL", "FAKE", "MISLEADING", "UNVERIFIED"]
    confidence_score: float
    analysis: str = Field(..., description="2-3 sentences explaining the 'why'")
    key_findings: List[str]
    source_metadata: Optional[SourceMetadata] = None
    grounding_citations: List[GroundingCitation] = []
    media_literacy: Optional[MediaLiteracy] = None
