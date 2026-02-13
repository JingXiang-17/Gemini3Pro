import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';

import 'confidence_gauge.dart';

class ResultCard extends StatelessWidget {
  final AnalysisResponse? result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we are in a mobile context (width < 600) using the parent constraints
        // or just by checking the screen width via MediaQuery if necessary,
        // but here we can rely on the ResponsiveLayout wrapper logic or just
        // make this widget responsive itself.
        // The prompt asks for:
        // Desktop: Side-by-side Row
        // Mobile: Stacked Column

        final isMobile = MediaQuery.of(context).size.width < 600;

        if (result == null) {
          return const Center(
            child: Text(
              "Waiting for analysis...",
              style: TextStyle(color: Colors.white24),
            ),
          );
        }

        final bool isReal = result!.verdict == 'REAL';
        final Color accentColor =
            isReal ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

        // Common Verdict Widget
        final verdictWidget = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isReal ? "REAL" : "FAKE",
              style: GoogleFonts.outfit(
                color: accentColor,
                fontSize: isMobile ? 24 : 32, // Adaptive Typography
                fontWeight: FontWeight.bold,
              ),
            ),
            if (result!.keyFindings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  result!.keyFindings.first,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );

        // Common Confidence Widget
        final confidenceWidget =
            ConfidenceGauge(score: result!.confidenceScore);

        if (isMobile) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              verdictWidget,
              const SizedBox(height: 20),
              // Constrain height for gauge in column
              SizedBox(height: 150, child: confidenceWidget),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: verdictWidget),
              Container(
                  width: 1,
                  height: 80,
                  color: Colors.white.withValues(alpha: 0.1)),
              Expanded(child: confidenceWidget),
            ],
          );
        }
      },
    );
  }
}
