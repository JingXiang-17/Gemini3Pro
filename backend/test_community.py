#!/usr/bin/env python3
"""
Test script for community voting feature
"""
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from community_database import CommunityDatabase

def test_community_database():
    """Test community database functionality."""
    print("=" * 60)
    print("Testing Community Voting Feature")
    print("=" * 60)
    
    # Initialize in-memory database
    db = CommunityDatabase(':memory:')
    print("✅ Database initialized")
    
    # Test 1: Post a claim
    claim_text = "The Earth is round"
    ai_verdict = "REAL"
    claim_id = db.post_claim(claim_text, ai_verdict)
    print(f"✅ Claim posted: {claim_id}")
    
    # Test 2: Retrieve claim
    claim = db.get_claim_by_text(claim_text)
    assert claim is not None, "Claim should exist"
    assert claim['claim_text'] == claim_text
    print(f"✅ Claim retrieved: {claim['claim_text'][:50]}...")
    
    # Test 3: Submit votes
    users_and_votes = [
        ("user1", True),   # Agrees with REAL verdict
        ("user2", True),   # Agrees with REAL verdict
        ("user3", False),  # Disagrees
        ("user4", True),   # Agrees with REAL verdict
    ]
    
    for user_id, vote in users_and_votes:
        success = db.submit_vote(claim_id, user_id, vote)
        assert success, f"Vote should succeed for {user_id}"
    print(f"✅ {len(users_and_votes)} votes submitted")
    
    # Test 4: Calculate trust score
    trust_score, vote_count = db.calculate_weighted_trust_score(claim_id)
    print(f"✅ Trust Score: {trust_score:.2f}% ({vote_count} votes)")
    assert vote_count == 4, "Should have 4 votes"
    assert trust_score > 50, "Trust score should be > 50% (3 out of 4 voted True)"
    
    # Test 5: Calculate user reputation
    # user1 voted correctly (True for REAL verdict)
    rep1 = db.calculate_user_reputation("user1")
    print(f"✅ User1 Reputation: {rep1:.4f} (voted correctly)")
    assert rep1 > 0, "Reputation should be positive for accurate vote"
    
    # user3 voted incorrectly (False for REAL verdict)
    rep3 = db.calculate_user_reputation("user3")
    print(f"✅ User3 Reputation: {rep3:.4f} (voted incorrectly)")
    assert rep3 == 0, "Reputation should be 0 for inaccurate vote"
    
    # Test 6: Top claims
    top_claims = db.get_top_claims(limit=5)
    assert len(top_claims) == 1, "Should have 1 claim"
    print(f"✅ Top claims retrieved: {len(top_claims)}")
    
    # Test 7: Search claims
    search_results = db.search_claims("Earth")
    assert len(search_results) == 1, "Should find the Earth claim"
    print(f"✅ Search results: {len(search_results)}")
    
    # Test 8: Post another claim
    claim_text2 = "The Moon landing was faked"
    ai_verdict2 = "FAKE"
    claim_id2 = db.post_claim(claim_text2, ai_verdict2)
    print(f"✅ Second claim posted: {claim_id2}")
    
    # Add votes to second claim
    db.submit_vote(claim_id2, "user5", False)  # Agrees with FAKE
    db.submit_vote(claim_id2, "user6", False)  # Agrees with FAKE
    
    # Calculate trust score for second claim
    trust_score2, vote_count2 = db.calculate_weighted_trust_score(claim_id2)
    print(f"✅ Trust Score for claim 2: {trust_score2:.2f}% ({vote_count2} votes)")
    assert trust_score2 < 50, "Trust score should be < 50% for FAKE claim with False votes"
    
    # Test 9: Top claims should now return 2 claims
    top_claims = db.get_top_claims(limit=5)
    assert len(top_claims) == 2, "Should have 2 claims"
    print(f"✅ Top claims now: {len(top_claims)}")
    
    # Test 10: Duplicate vote prevention
    success = db.submit_vote(claim_id, "user1", True)
    assert not success, "Duplicate vote should be prevented"
    print(f"✅ Duplicate vote prevention works")
    
    print("\n" + "=" * 60)
    print("All tests passed! ✅")
    print("=" * 60)
    
    # Print summary
    print("\nSummary of Test Data:")
    print(f"  Claim 1: '{claim_text}' - Trust: {trust_score:.1f}%")
    print(f"  Claim 2: '{claim_text2}' - Trust: {trust_score2:.1f}%")
    print(f"  User1 Reputation: {rep1:.4f}")
    print(f"  User3 Reputation: {rep3:.4f}")

if __name__ == '__main__':
    try:
        test_community_database()
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
