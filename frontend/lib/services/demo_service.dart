import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/grounding_models.dart';

class DemoService {
  static Future<AnalysisResponse?> loadLemonDemo() async {
    try {
      debugPrint(
          "🔍 DEBUG: Starting asset load for demo_lemon_analysis.json...");
      final String response =
          await rootBundle.loadString('assets/data/demo_lemon_analysis.json');
      debugPrint("🔍 DEBUG: Asset loaded. String length: ${response.length}");

      final data = await json.decode(response);
      debugPrint("🔍 DEBUG: JSON decoded successfully.");

      return AnalysisResponse.fromJson(data);
    } catch (e) {
      debugPrint("❌ DEBUG ERROR: Demo Load Failed: $e");
      return null;
    }
  }

  Future<void> simulateLoading() async {
    await Future.delayed(const Duration(seconds: 2));
  }
}
