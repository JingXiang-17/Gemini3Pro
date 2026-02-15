from typing import List, Optional, Literal
from pydantic import BaseModel, Field

class SourceMetadata(BaseModel):
    type: Literal["text", "url", "image", "document"]
    provided_url: Optional[str] = None
    page_title: Optional[str] = None

class GroundingCitation(BaseModel):
    title: str = ""
    url: Optional[str] = ""
    snippet: str = ""
    source_file: Optional[str] = None
    status: str = "live"

class MediaLiteracy(BaseModel):
    logical_fallacies: List[str]
    tone_analysis: str

class Segment(BaseModel):
    startIndex: int
    endIndex: int
    text: str

class GroundingSupport(BaseModel):
    segment: Segment
    groundingChunkIndices: List[int]
    confidenceScores: List[float] = []

class InputPart(BaseModel):
    type: Literal["text_claim", "image", "document", "url"]
    content: Optional[str] = None  # For text_claim
    mime_type: Optional[str] = None  # For image, document
    data: Optional[str] = None  # Base64 string for image, document
    value: Optional[str] = None  # For url

class AnalysisSettings(BaseModel):
    enable_grounding: bool = True
    forensic_depth: Literal["low", "medium", "high"] = "medium"

class AnalysisRequest(BaseModel):
    request_id: str
    parts: List[InputPart]
    settings: Optional[AnalysisSettings] = Field(default_factory=AnalysisSettings)

class Source(BaseModel):
    id: str
    title: str
    url: str
    cited_segment: str
    source_context: str
    favicon_url: Optional[str] = None

class AnalysisResponse(BaseModel):
    verdict: Literal["REAL", "FAKE", "MISLEADING", "UNVERIFIED"]
    confidence_score: float
    analysis: str = Field(..., description="2-3 sentences explaining the 'why'")
    key_findings: List[str]
    source_metadata: Optional[SourceMetadata] = None
    grounding_citations: List[GroundingCitation] = []
    grounding_supports: List[GroundingSupport] = []
    media_literacy: Optional[MediaLiteracy] = None
    sources: List[Source] = []
