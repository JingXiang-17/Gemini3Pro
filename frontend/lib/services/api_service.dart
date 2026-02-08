import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_analysis.dart';

class ApiService {
  // Update this URL to match your backend server
  // For Android emulator: use http://10.0.2.2:8000
  // For iOS simulator: use http://localhost:8000
  // For physical device: use your computer's IP address
  static const String baseUrl = 'http://localhost:8000';

  Future<NewsAnalysisResponse> analyzeNews(String newsText) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'news_text': newsText,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NewsAnalysisResponse.fromJson(data);
      } else {
        throw Exception('Failed to analyze news: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
