import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import 'confidence_gauge.dart';

class VerdictPane extends StatelessWidget {
  final AnalysisResponse? result;

  const VerdictPane({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              "Ready for Analysis",
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final bool isReal = result!.verdict == 'REAL';
    final Color accentColor =
        isReal ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verdict Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: accentColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  "VERDICT",
                  style: GoogleFonts.outfit(
                      color: accentColor.withValues(alpha: 0.8),
                      letterSpacing: 2.0,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isReal ? "REAL" : "FAKE",
                  style: GoogleFonts.outfit(
                    color: accentColor,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 20)
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Confidence Gauge
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: ConfidenceGauge(score: result!.confidenceScore),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Key Findings Mini-List
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("KEY FINDINGS",
                    style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...result!.keyFindings.take(3).map((finding) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Icon(Icons.circle,
                                size: 4, color: Color(0xFFD4AF37)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(finding,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.4))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
