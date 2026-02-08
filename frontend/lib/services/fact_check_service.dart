import 'dart:convert';
import 'package:http/http.dart' as http;

class FactCheckResult {
  final bool isValid;
  final double confidenceScore;
  final String analysis;
  final List<String> keyFindings;

  FactCheckResult({
    required this.isValid,
    required this.confidenceScore,
    required this.analysis,
    required this.keyFindings,
  });

  factory FactCheckResult.fromJson(Map<String, dynamic> json) {
    return FactCheckResult(
      isValid: json['is_valid'] ?? false,
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      analysis: json['analysis'] ?? '',
      keyFindings: List<String>.from(json['key_findings'] ?? []),
    );
  }
}

class FactCheckService {
  final String baseUrl = 'http://localhost:8000';

  Future<FactCheckResult> analyzeNews(String newsText) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'news_text': newsText}),
      );

      if (response.statusCode == 200) {
        return FactCheckResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to analyze news: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }
}
