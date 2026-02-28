import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _tourSeenKey = 'demo_tour_seen';

  Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tourSeenKey) ?? false;
  }

  Future<void> markTourAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourSeenKey, true);
  }

  /// Launches the 4-step demo tour in two phases.
  ///
  /// **Phase 1** — Step 1 (underlined text). User taps the target →
  /// [onSelectFirstSegment] fires to open the Evidence Tray.
  ///
  /// **Phase 2** — After a scroll animation centres the tray,
  /// Steps 2 (Evidence Tray), 3 (Evidence Lane), and 4 (Scanned Ring)
  /// play back-to-back.
  void showDemoTour(
    BuildContext context, {
    required GlobalKey firstSegmentKey,
    required GlobalKey evidenceTrayKey,
    required GlobalKey globalRingKey,
    required VoidCallback onSelectFirstSegment,
    GlobalKey? scannedRingKey,
    Function? onFinish,
  }) {
    debugPrint(
        "🎯 DEBUG: Phase 1 — First Segment: ${firstSegmentKey.currentContext != null}");

    _showPhase1(
      context,
      firstSegmentKey: firstSegmentKey,
      evidenceTrayKey: evidenceTrayKey,
      globalRingKey: globalRingKey,
      scannedRingKey: scannedRingKey,
      onSelectFirstSegment: onSelectFirstSegment,
      onFinish: onFinish,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PHASE 1 — A single-step tour highlighting the underlined text
  // ═══════════════════════════════════════════════════════════════════
  void _showPhase1(
    BuildContext context, {
    required GlobalKey firstSegmentKey,
    required GlobalKey evidenceTrayKey,
    required GlobalKey globalRingKey,
    required VoidCallback onSelectFirstSegment,
    GlobalKey? scannedRingKey,
    Function? onFinish,
  }) {
    final targets = <TargetFocus>[
      TargetFocus(
        identify: "ForensicBreakdown",
        keyTarget: firstSegmentKey,
        shape: ShapeLightFocus.RRect,
        radius: 8.0,
        paddingFocus: 10.0,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Step 1: The Forensic Breakdown",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "VeriScan identifies specific claims within the text. "
                    "Notice the underlines—each one is tied to verified data. "
                    "Tap here to investigate the evidence.",
                    style:
                        GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.85,
      onClickTarget: (target) {
        debugPrint(
            "🎯 Phase 1 — User tapped underline. Opening Evidence Tray…");
        onSelectFirstSegment();
      },
      onFinish: () {
        debugPrint("🎯 Phase 1 complete. Waiting for tray to render…");
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!context.mounted) return;
          _scrollAndShowPhase2(
            context,
            evidenceTrayKey: evidenceTrayKey,
            globalRingKey: globalRingKey,
            scannedRingKey: scannedRingKey,
            onFinish: onFinish,
          );
        });
      },
      onSkip: () {
        debugPrint("Tutorial Skipped");
        markTourAsSeen();
        onFinish?.call();
        return true;
      },
    ).show(context: context);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TRANSITION — Scroll the Evidence Tray into view, then Phase 2
  // ═══════════════════════════════════════════════════════════════════
  void _scrollAndShowPhase2(
    BuildContext context, {
    required GlobalKey evidenceTrayKey,
    required GlobalKey globalRingKey,
    GlobalKey? scannedRingKey,
    Function? onFinish,
  }) async {
    if (evidenceTrayKey.currentContext != null) {
      debugPrint("🎯 Scrolling Evidence Tray into view…");
      await Scrollable.ensureVisible(
        evidenceTrayKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    } else {
      debugPrint("⚠️ Evidence Tray key has no context — skipping scroll.");
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return;

    _showPhase2(
      context,
      evidenceTrayKey: evidenceTrayKey,
      globalRingKey: globalRingKey,
      scannedRingKey: scannedRingKey,
      onFinish: onFinish,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PHASE 2 — Steps 2, 3, 4
  // ═══════════════════════════════════════════════════════════════════
  void _showPhase2(
    BuildContext context, {
    required GlobalKey evidenceTrayKey,
    required GlobalKey globalRingKey,
    GlobalKey? scannedRingKey,
    Function? onFinish,
  }) {
    debugPrint(
        "🎯 DEBUG: Phase 2 — Tray: ${evidenceTrayKey.currentContext != null}, "
        "Lane: ${globalRingKey.currentContext != null}, "
        "ScannedRing: ${scannedRingKey?.currentContext != null}");

    final targets = <TargetFocus>[];

    // ── Step 2: The Audit Trail (Evidence Tray) ──
    if (evidenceTrayKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "AuditTrail",
          keyTarget: evidenceTrayKey,
          shape: ShapeLightFocus.RRect,
          radius: 8.0,
          paddingFocus: 20.0,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Step 2: The Audit Trail",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "This is the Evidence Tray. It reveals the high-fidelity "
                      "source text the AI extracted to verify the specific "
                      "claim you just selected.",
                      style:
                          GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    // ── Step 3: The Evidence Lane ──
    if (globalRingKey.currentContext != null) {
      try {
        final RenderBox box =
            globalRingKey.currentContext!.findRenderObject() as RenderBox;
        debugPrint(
            "🔍 DEBUG Step 3: Position: ${box.localToGlobal(Offset.zero)}");
        debugPrint("🔍 DEBUG Step 3: Size: ${box.size}");
      } catch (e) {
        debugPrint("⚠️ DEBUG Step 3: RenderBox error: $e");
      }

      targets.add(
        TargetFocus(
          identify: "EvidenceLane",
          keyTarget: globalRingKey,
          shape: ShapeLightFocus.RRect,
          radius: 12.0,
          paddingFocus: 20.0,
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(
                top: 100,
              ),
              builder: (context, controller) {
                final screenWidth = MediaQuery.of(context).size.width;
                final rightAreaWidth = screenWidth - 460;

                return Padding(
                  padding: const EdgeInsets.only(left: 440),
                  child: SizedBox(
                    width: rightAreaWidth > 300
                        ? 400
                        : rightAreaWidth.clamp(200, 400),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Step 3: The Audit Hierarchy",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD4AF37),
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "\u2022 Uploaded Lane: Stores your original files, links, "
                            "or text. This serves as the 'Claim Baseline' that "
                            "VeriScan audits.\n\n"
                            "\u2022 Cited Sources: Primary evidence selected by the "
                            "AI to build the forensic analysis.\n\n"
                            "\u2022 Scanned Context: Background medical data (like Mayo "
                            "Clinic) searched to verify accuracy without being "
                            "quoted directly.",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // ── Step 4: Forensic Veracity (Scanned Source Ring) ──
    if (scannedRingKey != null && scannedRingKey.currentContext != null) {
      try {
        final RenderBox box =
            scannedRingKey.currentContext!.findRenderObject() as RenderBox;
        debugPrint(
            "🔍 DEBUG Step 4: Position: ${box.localToGlobal(Offset.zero)}");
        debugPrint("🔍 DEBUG Step 4: Size: ${box.size}");
      } catch (e) {
        debugPrint("⚠️ DEBUG Step 4: RenderBox error: $e");
      }

      targets.add(
        TargetFocus(
          identify: "ForensicVeracity",
          keyTarget: scannedRingKey,
          shape: ShapeLightFocus.RRect,
          radius: 12.0,
          paddingFocus: 8.0,
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(
                top: 80,
              ),
              builder: (context, controller) {
                return Padding(
                  padding: const EdgeInsets.only(left: 440),
                  child: SizedBox(
                    width: 420,
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Step 4: Forensic Veracity",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD4AF37),
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "\u2022 Global Score: Shows the highest reliability found "
                            "among all evidence when no claim is selected.\n\n"
                            "\u2022 Local Score: Click a specific claim to see the "
                            "score update for only that sentence.",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      debugPrint("⚠️ No Phase 2 targets found. Tour ends here.");
      markTourAsSeen();
      onFinish?.call();
      return;
    }

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onClickTarget: (target) {
        debugPrint("🎯 Phase 2 — Target tapped: ${target.identify}");

        // Scroll the Lane into view before Step 3
        if (target.identify == "AuditTrail" &&
            globalRingKey.currentContext != null) {
          Scrollable.ensureVisible(
            globalRingKey.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }

        // Scroll scanned ring into view before Step 4
        if (target.identify == "EvidenceLane" &&
            scannedRingKey?.currentContext != null) {
          Scrollable.ensureVisible(
            scannedRingKey!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }

        // Step 4 clicked → open formula dialog → completion on close
        if (target.identify == "ForensicVeracity") {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!context.mounted) return;
            _showFormulaDialog(context, onClose: () {
              if (!context.mounted) return;
              _showCompletionOverlay(context);
            });
          });
        }
      },
      onFinish: () {
        debugPrint("🎯 Tour complete — transitioning to Live Mode.");
        markTourAsSeen();
        onFinish?.call();
      },
      onSkip: () {
        debugPrint("Tutorial Skipped");
        markTourAsSeen();
        onFinish?.call();
        return true;
      },
    ).show(context: context);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FORMULA DIALOG
  // ═══════════════════════════════════════════════════════════════════
  void _showFormulaDialog(BuildContext context, {VoidCallback? onClose}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side:
              BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.functions, color: Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 8),
            Text(
              "Factual Breakdown",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  "Score\u209B\u2091\u2091 = max( Conf\u1d62 \u00d7 Auth\u2c7c )",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Where:",
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _formulaRow("Conf\u1d62", "Grounding confidence from Gemini API"),
            const SizedBox(height: 4),
            _formulaRow(
                "Auth\u2c7c", "Domain authority weight (IFCN / verified)"),
            const SizedBox(height: 4),
            _formulaRow("max()", "Highest score across all source pairs"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onClose?.call();
            },
            child: Text(
              "CLOSE",
              style: GoogleFonts.outfit(color: const Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulaRow(String symbol, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            symbol,
            style: GoogleFonts.outfit(
              color: const Color(0xFFD4AF37),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        Expanded(
          child: Text(
            "— $description",
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  COMPLETION OVERLAY (Confetti-like celebration)
  // ═══════════════════════════════════════════════════════════════════
  void _showCompletionOverlay(BuildContext context) {
    final overlay = OverlayEntry(
      builder: (ctx) => _CompletionOverlay(
        onDismiss: () {},
      ),
    );

    Overlay.of(context).insert(overlay);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      overlay.remove();
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Completion Overlay Widget (celebratory transition animation)
// ═══════════════════════════════════════════════════════════════════════
class _CompletionOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const _CompletionOverlay({required this.onDismiss});

  @override
  State<_CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<_CompletionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2)),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _fadeIn.value * _fadeOut.value;
        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "🎉",
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Tour Complete!",
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFD4AF37),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Switching to Live Ingestion Mode…",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
