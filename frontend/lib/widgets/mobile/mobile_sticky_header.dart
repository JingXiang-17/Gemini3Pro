import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/grounding_models.dart';
import '../confidence_gauge.dart';

class MobileStickyHeader extends StatelessWidget {
  final AnalysisResponse? result;

  const MobileStickyHeader({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return _HeaderContent(result: result);
  }
}

class MobileStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AnalysisResponse? result;

  MobileStickyHeaderDelegate({required this.result});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Use a Stack to add a background blur effect when sticky
    return Material(
      color: Colors.black.withValues(alpha: shrinkOffset > 0 ? 0.9 : 1.0),
      child: _HeaderContent(result: result),
    );
  }

  @override
  double get maxExtent => 140.0;

  @override
  double get minExtent => 140.0;

  @override
  bool shouldRebuild(covariant MobileStickyHeaderDelegate oldDelegate) {
    return result != oldDelegate.result;
  }
}

class _HeaderContent extends StatelessWidget {
  final AnalysisResponse? result;

  const _HeaderContent({required this.result});

  @override
  Widget build(BuildContext context) {
    final bool hasResult = result != null;
    final bool isReal = hasResult && result!.verdict == 'REAL';
    final bool isUnverified = !hasResult || result!.verdict == 'UNVERIFIED';

    final Color accentColor = hasResult
        ? (isReal
            ? const Color(0xFF4CAF50)
            : (result!.verdict == 'UNVERIFIED'
                ? const Color(0xFFD4AF37)
                : const Color(0xFFE53935)))
        : const Color(0xFFD4AF37);

    return Container(
      height: 140, // Fixed height for constraints
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Prevent horizontal pushing
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verdict Card (45%)
          Expanded(
            flex: 45,
            child: Container(
              height: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnverified
                    ? Colors.black
                    : accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnverified
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                      : accentColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "VERDICT",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFD4AF37),
                      letterSpacing: 2.0,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hasResult ? result!.verdict : "---",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Trust Score Card (55%)
          Expanded(
            flex: 55,
            child: Container(
              height: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(
                            "TRUST",
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              letterSpacing: 1.5,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FittedBox(
                          child: Text(
                            "SCORE",
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              letterSpacing: 1.5,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Trust Gauge with Flexible to prevent overflow
                  Flexible(
                    flex: 3,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: ConfidenceGauge(
                              score: hasResult ? result!.confidenceScore : 0.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
