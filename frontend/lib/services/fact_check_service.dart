import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class FactCheckResult {
  final bool isValid;
  final double confidenceScore;
  final String analysis;
  final List<String> keyFindings;
  final List<Map<String, String>> groundingCitations;

  FactCheckResult({
    required this.isValid,
    required this.confidenceScore,
    required this.analysis,
    required this.keyFindings,
    required this.groundingCitations,
  });

  factory FactCheckResult.fromJson(Map<String, dynamic> json) {
    var citations = <Map<String, String>>[];
    if (json['grounding_citations'] != null) {
      json['grounding_citations'].forEach((v) {
        citations.add({
          'title': v['title']?.toString() ?? 'Source',
          'url': v['url']?.toString() ?? '',
          'snippet': v['snippet']?.toString() ?? '',
        });
      });
    }

    return FactCheckResult(
      isValid: json['verdict'] == 'REAL',
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      analysis: json['analysis']?.toString() ?? 'Analysis unavailable',
      keyFindings: (json['key_findings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      groundingCitations: citations,
    );
  }
}

class FactCheckService {
  final String baseUrl = 'http://localhost:8000';

  Future<FactCheckResult> analyzeNews({
    String? text,
    String? url,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));

      if (text != null && text.isNotEmpty) {
        request.fields['text'] = text;
      }
      if (url != null && url.isNotEmpty) {
        request.fields['url'] = url;
      }
      if (imageBytes != null && imageFilename != null) {
        // Determine mime type based on extension, or default to jpeg/png
        final mimeType =
            imageFilename.toLowerCase().endsWith('png') ? 'png' : 'jpeg';

        request.files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageFilename,
          contentType: MediaType('image', mimeType),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return FactCheckResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Failed to analyze: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }
}
