import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import 'confidence_gauge.dart';
import 'community_vote_box.dart';

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

    // Check if community vote is active to adjust trust meter size
    final bool hasCommunityVote = result != null;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          
          return Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Verdict Card - Fixed height
                  Container(
                    height: maxHeight * 0.15,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "VERDICT",
                          style: GoogleFonts.outfit(
                            color: accentColor.withValues(alpha: 0.8),
                            letterSpacing: 2.0,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isReal
                                ? "REAL"
                                : (result!.verdict == "UNVERIFIED"
                                    ? "UNVERIFIED"
                                    : "FAKE"),
                            style: GoogleFonts.outfit(
                              color: accentColor,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Trust Gauge - Responsive to community vote
                  Container(
                    height: hasCommunityVote ? maxHeight * 0.18 : maxHeight * 0.22,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: hasCommunityVote ? 0.8 : 1.0,
                        child: ConfidenceGauge(score: result!.confidenceScore),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Key Findings - Scrollable with fixed height
                  Container(
                    height: maxHeight * 0.28,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
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
                        Expanded(
                          child: ListView.builder(
                            itemCount: result!.keyFindings.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final finding = result!.keyFindings[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6.0),
                                      child: Icon(Icons.circle,
                                          size: 4, color: Color(0xFFD4AF37)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        finding,
                                        style: GoogleFonts.outfit(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Community Vote Box - Fixed height
                  Container(
                    height: maxHeight * 0.30,
                    child: CommunityVoteBox(
                      claimText: result?.analysis,
                      aiVerdict: result?.verdict,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
