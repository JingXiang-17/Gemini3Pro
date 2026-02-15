class CommunityVote {
  final bool vote; // true = supports (REAL), false = rejects (FAKE)
  final String userId;
  final DateTime timestamp;

  CommunityVote({
    required this.vote,
    required this.userId,
    required this.timestamp,
  });

  factory CommunityVote.fromJson(Map<String, dynamic> json) {
    return CommunityVote(
      vote: json['vote'] as bool,
      userId: json['user_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vote': vote,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class CommunityClaimData {
  final bool exists;
  final String? claimId;
  final String? claimText;
  final String? aiVerdict;
  final double trustScore;
  final int voteCount;
  final DateTime? createdAt;
  final String message;

  CommunityClaimData({
    required this.exists,
    this.claimId,
    this.claimText,
    this.aiVerdict,
    this.trustScore = 0.0,
    this.voteCount = 0,
    this.createdAt,
    this.message = '',
  });

  factory CommunityClaimData.fromJson(Map<String, dynamic> json) {
    return CommunityClaimData(
      exists: json['exists'] as bool? ?? false,
      claimId: json['claim_id'] as String?,
      claimText: json['claim_text'] as String?,
      aiVerdict: json['ai_verdict'] as String?,
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      message: json['message'] as String? ?? '',
    );
  }
}

class UserReputation {
  final String userId;
  final int totalVotes;
  final int accurateVotes;
  final double reputationScore;
  final double accuracyPercentage;
  final DateTime? lastUpdated;

  UserReputation({
    required this.userId,
    required this.totalVotes,
    required this.accurateVotes,
    required this.reputationScore,
    required this.accuracyPercentage,
    this.lastUpdated,
  });

  factory UserReputation.fromJson(Map<String, dynamic> json) {
    return UserReputation(
      userId: json['user_id'] as String,
      totalVotes: json['total_votes'] as int,
      accurateVotes: json['accurate_votes'] as int,
      reputationScore: (json['reputation_score'] as num).toDouble(),
      accuracyPercentage: (json['accuracy_percentage'] as num).toDouble(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
    );
  }
}

class ClaimSummary {
  final String claimId;
  final String claimText;
  final String aiVerdict;
  final double trustScore;
  final int voteCount;
  final DateTime createdAt;

  ClaimSummary({
    required this.claimId,
    required this.claimText,
    required this.aiVerdict,
    required this.trustScore,
    required this.voteCount,
    required this.createdAt,
  });

  factory ClaimSummary.fromJson(Map<String, dynamic> json) {
    return ClaimSummary(
      claimId: json['claim_id'] as String,
      claimText: json['claim_text'] as String,
      aiVerdict: json['ai_verdict'] as String,
      trustScore: (json['trust_score'] as num).toDouble(),
      voteCount: json['vote_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PostClaimResponse {
  final bool success;
  final String claimId;
  final String message;

  PostClaimResponse({
    required this.success,
    required this.claimId,
    required this.message,
  });

  factory PostClaimResponse.fromJson(Map<String, dynamic> json) {
    return PostClaimResponse(
      success: json['success'] as bool,
      claimId: json['claim_id'] as String,
      message: json['message'] as String,
    );
  }
}

class VoteResponse {
  final bool success;
  final double trustScore;
  final int voteCount;
  final String message;

  VoteResponse({
    required this.success,
    this.trustScore = 0.0,
    this.voteCount = 0,
    required this.message,
  });

  factory VoteResponse.fromJson(Map<String, dynamic> json) {
    return VoteResponse(
      success: json['success'] as bool,
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      message: json['message'] as String,
    );
  }
}
