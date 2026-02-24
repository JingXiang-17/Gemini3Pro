class VoteEntry {
  final String userId;
  final String userVerdict;
  final String? notes;
  final DateTime timestamp;

  VoteEntry({
    required this.userId,
    required this.userVerdict,
    this.notes,
    required this.timestamp,
  });

  factory VoteEntry.fromJson(Map<String, dynamic> json) {
    return VoteEntry(
      userId: json['user_id'] as String,
      userVerdict: json['user_verdict'] as String,
      notes: json['notes'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class ClaimDiscussion {
  final String claimId;
  final String claimText;
  final String aiVerdict;
  final double trustScore;
  final int voteCount;
  final DateTime? createdAt;
  final List<VoteEntry> votes;

  ClaimDiscussion({
    required this.claimId,
    required this.claimText,
    required this.aiVerdict,
    required this.trustScore,
    required this.voteCount,
    this.createdAt,
    required this.votes,
  });

  factory ClaimDiscussion.fromJson(Map<String, dynamic> json) {
    return ClaimDiscussion(
      claimId: json['claim_id'] as String,
      claimText: json['claim_text'] as String,
      aiVerdict: json['ai_verdict'] as String,
      trustScore: (json['trust_score'] as num).toDouble(),
      voteCount: json['vote_count'] as int,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      votes: (json['votes'] as List)
          .map((vote) => VoteEntry.fromJson(vote as Map<String, dynamic>))
          .toList(),
    );
  }
}
