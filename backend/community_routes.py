from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import logging
from community_database import CommunityDatabase

logger = logging.getLogger(__name__)

# Initialize database
community_db = CommunityDatabase()

# Create router
router = APIRouter(prefix="/community", tags=["community"])

# Request/Response Models
class ClaimRequest(BaseModel):
    claim_text: str

class PostClaimRequest(BaseModel):
    claim_text: str
    ai_verdict: str

class VoteRequest(BaseModel):
    claim_id: str
    user_id: str
    vote: Optional[bool] = None  # Backward-compatible payload
    user_verdict: Optional[str] = None  # Legit / Suspect / Fake
    notes: Optional[str] = None

class SearchRequest(BaseModel):
    query: str

# Routes
@router.post("/claim")
async def get_claim_data(request: ClaimRequest):
    """Get community data for a specific claim."""
    try:
        claim = community_db.get_claim_by_text(request.claim_text)
        
        if not claim:
            return {
                "exists": False,
                "claim_id": None,
                "message": "Claim not found in community database"
            }
        
        trust_score, vote_count = community_db.calculate_weighted_trust_score(claim['claim_id'])
        
        return {
            "exists": True,
            "claim_id": claim['claim_id'],
            "claim_text": claim['claim_text'],
            "ai_verdict": claim['ai_verdict'],
            "trust_score": round(trust_score, 2),
            "vote_count": vote_count,
            "created_at": claim['created_at']
        }
    except Exception as e:
        logger.error(f"Error getting claim data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/post")
async def post_claim(request: PostClaimRequest):
    """Post a new claim to the community."""
    try:
        claim_id = community_db.post_claim(request.claim_text, request.ai_verdict)
        
        return {
            "success": True,
            "claim_id": claim_id,
            "message": "Claim posted to community successfully"
        }
    except Exception as e:
        logger.error(f"Error posting claim: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/vote")
async def submit_vote(request: VoteRequest):
    """Submit a community vote."""
    try:
        normalized_verdict = (request.user_verdict or '').strip().upper()

        resolved_vote = request.vote
        if resolved_vote is None:
            if normalized_verdict == 'LEGIT':
                resolved_vote = True
            elif normalized_verdict in ('SUSPECT', 'FAKE'):
                resolved_vote = False

        if resolved_vote is None:
            raise HTTPException(
                status_code=400,
                detail="Provide either vote (bool) or user_verdict (Legit/Suspect/Fake)"
            )

        if not normalized_verdict:
            normalized_verdict = 'LEGIT' if resolved_vote else 'FAKE'

        success = community_db.submit_vote(
            claim_id=request.claim_id,
            user_id=request.user_id,
            vote=resolved_vote,
            user_verdict=normalized_verdict,
            notes=request.notes,
        )
        
        if not success:
            return {
                "success": False,
                "message": "You have already voted on this claim"
            }
        
        # Get updated trust score
        trust_score, vote_count = community_db.calculate_weighted_trust_score(request.claim_id)
        
        return {
            "success": True,
            "trust_score": round(trust_score, 2),
            "vote_count": vote_count,
            "message": "Vote submitted successfully"
        }
    except Exception as e:
        logger.error(f"Error submitting vote: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/top")
async def get_top_claims(limit: int = 5):
    """Get top voted claims."""
    try:
        claims = community_db.get_top_claims(limit)
        
        return {
            "success": True,
            "claims": [
                {
                    "claim_id": c['claim_id'],
                    "claim_text": c['claim_text'],
                    "ai_verdict": c['ai_verdict'],
                    "trust_score": round(c['trust_score'], 2),
                    "vote_count": c['vote_count'],
                    "created_at": c['created_at']
                }
                for c in claims
            ]
        }
    except Exception as e:
        logger.error(f"Error getting top claims: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/search")
async def search_claims(request: SearchRequest):
    """Search community claims by text."""
    try:
        claims = community_db.search_claims(request.query)
        
        return {
            "success": True,
            "found": len(claims) > 0,
            "claims": [
                {
                    "claim_id": c['claim_id'],
                    "claim_text": c['claim_text'],
                    "ai_verdict": c['ai_verdict'],
                    "trust_score": round(c['trust_score'], 2),
                    "vote_count": c['vote_count'],
                    "created_at": c['created_at']
                }
                for c in claims
            ]
        }
    except Exception as e:
        logger.error(f"Error searching claims: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reputation/{user_id}")
async def get_user_reputation(user_id: str):
    """Get user reputation statistics."""
    try:
        reputation = community_db.get_user_reputation(user_id)
        
        return {
            "success": True,
            "user_id": reputation['user_id'],
            "total_votes": reputation['total_votes'],
            "accurate_votes": reputation['accurate_votes'],
            "reputation_score": round(reputation['reputation_score'], 4),
            "accuracy_percentage": round(
                (reputation['accurate_votes'] / reputation['total_votes'] * 100)
                if reputation['total_votes'] > 0 else 0,
                2
            ),
            "last_updated": reputation['last_updated']
        }
    except Exception as e:
        logger.error(f"Error getting user reputation: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/discussion/{claim_id}")
async def get_claim_discussion(claim_id: str):
    """Get claim discussion with all votes and notes."""
    try:
        logger.info(f"Fetching discussion for claim_id: {claim_id}")
        discussion = community_db.get_claim_discussion(claim_id)
        
        if not discussion:
            logger.warning(f"Claim not found: {claim_id}")
            # Return empty discussion structure instead of 404
            return {
                "success": True,
                "claim_id": claim_id,
                "claim_text": "Claim not found",
                "ai_verdict": "Unknown",
                "trust_score": 0.0,
                "vote_count": 0,
                "created_at": None,
                "votes": []
            }
        
        logger.info(f"Found claim with {len(discussion['votes'])} votes")
        return {
            "success": True,
            "claim_id": discussion['claim_id'],
            "claim_text": discussion['claim_text'],
            "ai_verdict": discussion['ai_verdict'],
            "trust_score": round(discussion['trust_score'], 2),
            "vote_count": discussion['vote_count'],
            "created_at": discussion['created_at'],
            "votes": discussion['votes']
        }
    except Exception as e:
        logger.error(f"Error getting claim discussion: {e}")
        raise HTTPException(status_code=500, detail=str(e))
