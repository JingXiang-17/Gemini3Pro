import 'dart:math';
import 'dart:ui'; // Required for lerpDouble
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/juicy_button.dart';
import '../widgets/unified_sidebar.dart';

class DashboardLandingView extends StatefulWidget {
  final VoidCallback onStartAnalysis;
  const DashboardLandingView({
    super.key,
    required this.onStartAnalysis,
  });

  @override
  State<DashboardLandingView> createState() => _DashboardLandingViewState();
}

class _DashboardLandingViewState extends State<DashboardLandingView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Row(
        children: [
          const UnifiedSidebar(activeIndex: 0),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // 2. THE NEW HEADER (Logo + Title Layout)
                SliverPersistentHeader(
                  pinned: false,
                  floating: false,
                  delegate: _LandingHeaderDelegate(
                    minHeight: 140.0, // Compact when scrolled
                    maxHeight: 200.0, // Tall when at the top
                  ),
                ),

                // 3. SCROLLABLE CONTENT BODY
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 40),
                    child: Column(
                      children: [
                        // --- SECTION 1: WHAT IS VERISCAN? ---
                        _buildSectionTitle("WHAT IS VERISCAN?"),
                        const SizedBox(height: 20),
                        _buildGlassBox(
                          child: Text(
                            "VeriScan is your advanced command center for digital integrity. "
                            "We bridge the gap between 'viral' and 'verified' "
                            "by cross-referencing global archives and live data in real-time.",
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildStartButton(),

                        const SizedBox(height: 80),

                        // --- SECTION 2: WHY VERISCAN? ---
                        _buildSectionTitle("WHY VERISCAN?"),
                        const SizedBox(height: 30),
                        Wrap(
                          spacing: 30,
                          runSpacing: 40,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildImageFeature("Deep Forensic\nAnalysis",
                                "assets/images/why_deep.png"),
                            _buildImageFeature("Transparent\nEvidence Links",
                                "assets/images/why_link.png"),
                            _buildImageFeature("Multi-Modal\nVerification",
                                "assets/images/why_multi.png"),
                            _buildImageFeature("Instant\nTrust Scoring",
                                "assets/images/why_trust.png"),
                          ],
                        ),
                        const SizedBox(height: 50),
                        const SizedBox(height: 80),

                        // --- SECTION 3: HOW IT WORKS ---
                        _buildSectionTitle("HOW IT WORKS"),
                        const SizedBox(height: 30),
                        _buildHowItWorksSection(context),

                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildStartButton() {
    // 1. WE WRAP IT IN THE NEW JUICYBUTTON
    return JuicyButton(
      // 2. We move the action up here so the 200ms delay works
      onTap: widget.onStartAnalysis,

      child: ConstrainedBox(
        constraints:
            const BoxConstraints(minWidth: 180, maxWidth: 300, minHeight: 60),
        child: ElevatedButton(
          // 3. We leave this empty. JuicyButton handles the click now!
          // (If we make it null, Flutter turns the button grey, so we use () {})
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            elevation: 10,
            shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.radar),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  "START NEW ANALYSIS",
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: const Color(0xFFD4AF37),
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildGlassBox({required Widget child}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.6),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildImageFeature(String title, String imagePath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 0),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksSection(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final steps = [
      _buildImageStep("1. INGEST", "Paste text or upload media",
          "assets/images/how_ingest.png"),
      _buildImageStep("2. ANALYZE", "AI cross-checks global data",
          "assets/images/how_analyze.png"),
      _buildImageStep("3. VERDICT", "Get Trust Score & citations",
          "assets/images/how_verdict.png"),
    ];

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          steps[0],
          _buildArrow(),
          steps[1],
          _buildArrow(),
          steps[2],
        ],
      );
    } else {
      return Column(
        children: [
          steps[0],
          _buildArrow(vertical: true),
          steps[1],
          _buildArrow(vertical: true),
          steps[2],
        ],
      );
    }
  }

  Widget _buildImageStep(String title, String sub, String imagePath) {
    return Column(
      children: [
        Container(
          height: 90,
          width: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 0),
            ],
          ),
          child: ClipOval(
            child: Image.asset(imagePath, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: GoogleFonts.outfit(
                color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(sub,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildArrow({bool vertical = false}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Icon(
        vertical ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
        color: Colors.white12,
        size: 30,
      ),
    );
  }
}

// ==============================================================================
// 4. THE HEADER DELEGATE (Mobile Overflow Fixed)
// ==============================================================================
class _LandingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;

  _LandingHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double progress = min(1.0, shrinkOffset / (maxHeight - minHeight));

    final double logoSize = lerpDouble(80, 45, progress)!;
    final double titleSize = lerpDouble(19, 17, progress)!;
    final double sloganSize = lerpDouble(14, 13, progress)!;
    final double topPadding = lerpDouble(20, 50, progress)!;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border:
            Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 1.0)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A. BACKGROUND GRADIENT
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1B2A),
                  const Color(0xFF0D0D0D).withValues(alpha: progress),
                ],
              ),
            ),
          ),

          // B. THE CENTERED CONTENT
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding, left: 60, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- HERO LANDING PAD 1: THE LOGO ---
                  Hero(
                    tag: 'veriscan_logo',
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFD4AF37), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.3 * (1 - progress)),
                                blurRadius: 15)
                          ]),
                      child: Center(
                        child: Icon(Icons.shield,
                            color: const Color(0xFFD4AF37),
                            size: logoSize * 0.6),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- HERO LANDING PAD 2: THE TITLE ---
                        Hero(
                          tag: 'veriscan_title',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              "VERISCAN: FORENSIC TRUTH ENGINE",
                              style: GoogleFonts.outfit(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),

                        // --- HERO LANDING PAD 3: THE SLOGAN ---
                        Hero(
                          tag: 'veriscan_slogan',
                          child: Material(
                            type: MaterialType.transparency,
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "VERIFY",
                                    style: GoogleFonts.outfit(
                                      fontSize: sloganSize,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFD4AF37),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ", before you trust anything.",
                                    style: GoogleFonts.outfit(
                                      fontSize: sloganSize,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(covariant _LandingHeaderDelegate oldDelegate) => true;
}
