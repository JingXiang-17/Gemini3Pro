import sqlite3
import hashlib
import logging
import os
from datetime import datetime
from typing import List, Dict, Optional, Tuple
import math

logger = logging.getLogger(__name__)

# On Cloud Run, the filesystem is read-only except for /tmp
# Detect if we're in a cloud environment and use /tmp accordingly
_IS_CLOUD_RUN = os.environ.get('K_SERVICE') is not None  # Cloud Run sets this env var
_DEFAULT_DB_PATH = '/tmp/community.db' if _IS_CLOUD_RUN else 'community.db'

class CommunityDatabase:
    def __init__(self, db_path: str = _DEFAULT_DB_PATH):
        self.db_path = db_path
        self._connection = None
        # For in-memory databases, we need to keep connection alive
        self._is_memory = (db_path == ':memory:')
        self.init_database()
    
    def get_connection(self):
        """Get a database connection."""
        if self._is_memory:
            # For in-memory databases, reuse the same connection
            if self._connection is None:
                self._connection = sqlite3.connect(self.db_path)
                self._connection.row_factory = sqlite3.Row
            return self._connection
        else:
            # For file-based databases, create new connections
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row
            return conn
    
    def _close_connection(self, conn):
        """Close connection if not using in-memory database."""
        if not self._is_memory:
            conn.close()
    
    def init_database(self):
        """Initialize database tables."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Claims table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS claims (
                claim_id TEXT PRIMARY KEY,
                claim_text TEXT NOT NULL,
                ai_verdict TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                total_votes INTEGER DEFAULT 0
            )
        """)
        
        # Votes table (legacy)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS votes (
                vote_id INTEGER PRIMARY KEY AUTOINCREMENT,
                claim_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                vote BOOLEAN NOT NULL,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (claim_id) REFERENCES claims(claim_id),
                UNIQUE(claim_id, user_id)
            )
        """)

        # Community verdicts table (active)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS community_verdicts (
                verdict_id INTEGER PRIMARY KEY AUTOINCREMENT,
                claim_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                user_verdict TEXT NOT NULL,
                notes TEXT,
                vote BOOLEAN NOT NULL,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (claim_id) REFERENCES claims(claim_id),
                UNIQUE(claim_id, user_id)
            )
        """)
        
        # User reputation table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS user_reputation (
                user_id TEXT PRIMARY KEY,
                total_votes INTEGER DEFAULT 0,
                accurate_votes INTEGER DEFAULT 0,
                reputation_score REAL DEFAULT 0.0,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        if not self._is_memory:
            self._close_connection(conn)
        logger.info("Community database initialized successfully")
    
    def generate_claim_id(self, claim_text: str) -> str:
        """Generate a unique claim ID from claim text."""
        return hashlib.sha256(claim_text.lower().strip().encode()).hexdigest()[:16]
    
    def post_claim(self, claim_text: str, ai_verdict: str) -> str:
        """Post a new claim to the community."""
        claim_id = self.generate_claim_id(claim_text)
        
        conn = self.get_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                INSERT INTO claims (claim_id, claim_text, ai_verdict, created_at)
                VALUES (?, ?, ?, ?)
            """, (claim_id, claim_text, ai_verdict, datetime.now()))
            conn.commit()
            logger.info(f"Claim posted: {claim_id}")
        except sqlite3.IntegrityError:
            logger.info(f"Claim already exists: {claim_id}")
        finally:
            self._close_connection(conn)
        
        return claim_id
    
    def get_claim(self, claim_id: str) -> Optional[Dict]:
        """Get claim details."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM claims WHERE claim_id = ?
        """, (claim_id,))
        
        row = cursor.fetchone()
        self._close_connection(conn)
        
        if row:
            return dict(row)
        return None
    
    def get_claim_by_text(self, claim_text: str) -> Optional[Dict]:
        """Get claim by text."""
        claim_id = self.generate_claim_id(claim_text)
        return self.get_claim(claim_id)
    
    def submit_vote(
        self,
        claim_id: str,
        user_id: str,
        vote: bool,
        user_verdict: Optional[str] = None,
        notes: Optional[str] = None,
    ) -> bool:
        """Submit a vote for a claim."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                SELECT claim_id FROM claims WHERE claim_id = ?
            """, (claim_id,))

            if cursor.fetchone() is None:
                logger.warning(f"Claim not found for vote submission: {claim_id}")
                return False

            normalized_verdict = (user_verdict or ('LEGIT' if vote else 'FAKE')).strip().upper()

            # Insert verdict
            cursor.execute("""
                INSERT INTO community_verdicts
                (claim_id, user_id, user_verdict, notes, vote, timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (claim_id, user_id, normalized_verdict, notes, vote, datetime.now()))
            
            # Update claim vote count
            cursor.execute("""
                UPDATE claims
                SET total_votes = total_votes + 1
                WHERE claim_id = ?
            """, (claim_id,))
            
            conn.commit()
            logger.info(
                "Vote submitted: claim=%s, user=%s, vote=%s, verdict=%s",
                claim_id,
                user_id,
                vote,
                normalized_verdict,
            )
            
            # Update user reputation
            self._update_user_reputation(user_id)
            
            return True
        except sqlite3.IntegrityError:
            logger.warning(f"User {user_id} already voted on claim {claim_id}")
            return False
        finally:
            self._close_connection(conn)
    
    def calculate_user_reputation(self, user_id: str) -> float:
        """
        Calculate user reputation score.
        Formula: R_u = (accurate_votes / total_votes) × log(total_votes + 1)
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Get user's votes
        cursor.execute("""
            SELECT v.vote, c.ai_verdict
            FROM community_verdicts v
            JOIN claims c ON v.claim_id = c.claim_id
            WHERE v.user_id = ?
        """, (user_id,))
        
        votes = cursor.fetchall()
        self._close_connection(conn)
        
        if not votes:
            return 0.0
        
        total_votes = len(votes)
        accurate_votes = 0
        
        # Count accurate votes
        for vote in votes:
            user_vote = vote['vote']  # True/False (1/0)
            ai_verdict = vote['ai_verdict']  # "REAL" or "FAKE"
            
            # Vote is accurate if:
            # - User voted True (1) and AI said "REAL"
            # - User voted False (0) and AI said "FAKE"
            if (user_vote and ai_verdict == "REAL") or (not user_vote and ai_verdict == "FAKE"):
                accurate_votes += 1
        
        # Calculate reputation
        accuracy_ratio = accurate_votes / total_votes if total_votes > 0 else 0
        reputation = accuracy_ratio * math.log(total_votes + 1)
        
        return reputation
    
    def _update_user_reputation(self, user_id: str):
        """Update user reputation in database."""
        reputation = self.calculate_user_reputation(user_id)
        
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Get vote counts
        cursor.execute("""
            SELECT COUNT(*) as total_votes FROM community_verdicts WHERE user_id = ?
        """, (user_id,))
        total_votes = cursor.fetchone()['total_votes']
        
        cursor.execute("""
            SELECT COUNT(*) as accurate_votes
            FROM community_verdicts v
            JOIN claims c ON v.claim_id = c.claim_id
            WHERE v.user_id = ?
            AND ((v.vote = 1 AND c.ai_verdict = 'REAL') OR (v.vote = 0 AND c.ai_verdict = 'FAKE'))
        """, (user_id,))
        accurate_votes = cursor.fetchone()['accurate_votes']
        
        cursor.execute("""
            INSERT INTO user_reputation (user_id, total_votes, accurate_votes, reputation_score, last_updated)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                total_votes = excluded.total_votes,
                accurate_votes = excluded.accurate_votes,
                reputation_score = excluded.reputation_score,
                last_updated = excluded.last_updated
        """, (user_id, total_votes, accurate_votes, reputation, datetime.now()))
        
        conn.commit()
        self._close_connection(conn)
    
    def calculate_weighted_trust_score(self, claim_id: str) -> Tuple[float, int]:
        """
        Calculate weighted trust score for a claim.
        Formula: T_s = Σ(V_i × R_{u,i}) / Σ(R_{u,i})
        Returns: (trust_percentage, vote_count)
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Get all votes with user reputations
        cursor.execute("""
            SELECT v.vote, COALESCE(ur.reputation_score, 0.1) as reputation
            FROM community_verdicts v
            LEFT JOIN user_reputation ur ON v.user_id = ur.user_id
            WHERE v.claim_id = ?
        """, (claim_id,))
        
        votes = cursor.fetchall()
        self._close_connection(conn)
        
        if not votes:
            return 0.0, 0
        
        numerator = 0.0
        denominator = 0.0
        
        for vote in votes:
            vote_value = 1.0 if vote['vote'] else 0.0
            reputation = max(vote['reputation'], 0.1)  # Minimum reputation of 0.1
            
            numerator += vote_value * reputation
            denominator += reputation
        
        if denominator == 0:
            return 0.0, len(votes)
        
        trust_score = (numerator / denominator) * 100  # Convert to percentage
        return trust_score, len(votes)
    
    def get_top_claims(self, limit: int = 5) -> List[Dict]:
        """Get top voted claims."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM claims
            ORDER BY total_votes DESC, created_at DESC
            LIMIT ?
        """, (limit,))
        
        rows = cursor.fetchall()
        self._close_connection(conn)
        
        claims = []
        for row in rows:
            claim_dict = dict(row)
            trust_score, vote_count = self.calculate_weighted_trust_score(row['claim_id'])
            claim_dict['trust_score'] = trust_score
            claim_dict['vote_count'] = vote_count
            claims.append(claim_dict)
        
        return claims
    
    def search_claims(self, query: str) -> List[Dict]:
        """Search claims by text."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM claims
            WHERE claim_text LIKE ?
            ORDER BY total_votes DESC, created_at DESC
        """, (f"%{query}%",))
        
        rows = cursor.fetchall()
        self._close_connection(conn)
        
        claims = []
        for row in rows:
            claim_dict = dict(row)
            trust_score, vote_count = self.calculate_weighted_trust_score(row['claim_id'])
            claim_dict['trust_score'] = trust_score
            claim_dict['vote_count'] = vote_count
            claims.append(claim_dict)
        
        return claims
    
    def get_user_reputation(self, user_id: str) -> Dict:
        """Get user reputation statistics."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM user_reputation WHERE user_id = ?
        """, (user_id,))
        
        row = cursor.fetchone()
        self._close_connection(conn)
        
        if row:
            return dict(row)
        
        # Return default if user hasn't voted yet
        return {
            'user_id': user_id,
            'total_votes': 0,
            'accurate_votes': 0,
            'reputation_score': 0.0,
            'last_updated': None
        }
    
    def get_claim_discussion(self, claim_id: str) -> Dict:
        """Get claim details with all votes/notes for discussion view."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Get claim details
        cursor.execute("""
            SELECT * FROM claims WHERE claim_id = ?
        """, (claim_id,))
        
        claim_row = cursor.fetchone()
        if not claim_row:
            self._close_connection(conn)
            return None
        
        claim_data = dict(claim_row)
        
        # Get all votes with notes
        cursor.execute("""
            SELECT user_id, user_verdict, notes, timestamp
            FROM community_verdicts
            WHERE claim_id = ?
            ORDER BY timestamp DESC
        """, (claim_id,))
        
        votes_rows = cursor.fetchall()
        self._close_connection(conn)
        
        votes = [dict(row) for row in votes_rows]
        
        # Calculate trust score
        trust_score, vote_count = self.calculate_weighted_trust_score(claim_id)
        
        return {
            'claim_id': claim_data['claim_id'],
            'claim_text': claim_data['claim_text'],
            'ai_verdict': claim_data['ai_verdict'],
            'trust_score': trust_score,
            'vote_count': vote_count,
            'created_at': claim_data['created_at'],
            'votes': votes
        }
