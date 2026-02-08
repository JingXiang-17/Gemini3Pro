class NewsAnalysisResponse {
  final bool isValid;
  final double confidenceScore;
  final String analysis;
  final List<String> keyFindings;

  NewsAnalysisResponse({
    required this.isValid,
    required this.confidenceScore,
    required this.analysis,
    required this.keyFindings,
  });

  factory NewsAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return NewsAnalysisResponse(
      isValid: json['is_valid'] ?? false,
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      analysis: json['analysis'] ?? '',
      keyFindings: List<String>.from(json['key_findings'] ?? []),
    );
  }
}
