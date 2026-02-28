import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fact_check_service.dart';
import '../models/grounding_models.dart';
import '../widgets/veriscan_interactive_text.dart';
import '../utils/demo_manager.dart';
import '../services/demo_service.dart';
import '../widgets/confidence_gauge.dart';
import '../services/onboarding_service.dart';

class FactCheckScreen extends StatefulWidget {
  const FactCheckScreen({super.key});

  @override
  State<FactCheckScreen> createState() => _FactCheckScreenState();
}

class _FactCheckScreenState extends State<FactCheckScreen> {
  final TextEditingController _controller = TextEditingController();
  final FactCheckService _service = FactCheckService();
  AnalysisResponse? _result;
  bool _isLoading = false;
  bool _isRateLimited = false;
  bool _isRecoveringFromHallucination = false;
  bool _isHydratingDemo = false;
  GroundingSupport? _activeSupport;

  // Tutorial Keys
  final GlobalKey _analysisKey = GlobalKey();
  final GlobalKey _evidenceTrayKey = GlobalKey();
  final GlobalKey _globalRingKey = GlobalKey();
  final GlobalKey _firstSegmentKey = GlobalKey();

  final OnboardingService _onboardingService = OnboardingService();

  @override
  void initState() {
    super.initState();
    debugPrint(
        "🔍 DEBUG: FactCheckScreen initState. isDemoMode: ${DemoManager.isDemoMode}");
    if (DemoManager.isDemoMode) {
      debugPrint("🔍 DEBUG: Demo Mode detected in FactCheckScreen.");
      _handleDemoHydration();
    }
  }

  @override
  void dispose() {
    DemoManager.isDemoMode = false;
    super.dispose();
  }

  Future<void> _handleDemoHydration() async {
    setState(() {
      _isLoading = true;
      _isHydratingDemo = true;
      _result = null;
      _activeSupport = null; // Reset selection state for demo
    });

    try {
      final demoService = DemoService();
      await demoService.simulateLoading();
      final result = await DemoService.loadLemonDemo();
      debugPrint(
          "🔍 DEBUG: Demo data received: ${result != null ? 'SUCCESS' : 'NULL'}");

      if (result == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isHydratingDemo = false;
          });
          DemoManager.isDemoMode = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("Forensic Asset not found. Reverting to Live Mode.")),
          );
        }
        return;
      }

      setState(() {
        _result = result;
      });

      // Launch Onboarding Tour immediately once mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint("🔍 DEBUG: Attempting to launch Onboarding Tour...");
          _onboardingService.showDemoTour(
            context,
            firstSegmentKey: _firstSegmentKey,
            evidenceTrayKey: _evidenceTrayKey,
            globalRingKey: _globalRingKey,
            onSelectFirstSegment: () {
              if (_result != null && _result!.groundingSupports.isNotEmpty) {
                _handleSupportSelected(_result!.groundingSupports.first);
              }
            },
            onFinish: () {
              if (mounted) {
                setState(() {
                  DemoManager.isDemoMode = false;
                });
              }
            },
          );
        }
      });
    } catch (e) {
      debugPrint('DEMO HYDRATION ERROR: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isHydratingDemo = false;
        });
        DemoManager.isDemoMode = false;

        String errorMessage = "Demo Hydration Failed.";
        if (e is TypeError) {
          errorMessage = "Forensic Data Corrupted. Reverting to Live Mode.";
        } else {
          errorMessage = "Forensic Asset not found. Reverting to Live Mode.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _isHydratingDemo = false;
        });
      }
    }
  }

  Future<void> _handleVerify() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
      _isRateLimited = false;
      _isRecoveringFromHallucination = false;
    });

    try {
      final result = await _service.analyzeNews(text: _controller.text);
      setState(() {
        _result = result;
        _isRateLimited = result.verdict == 'RATE_LIMIT_ERROR';
        _isRecoveringFromHallucination =
            result.verdict == 'RECOVERING_FROM_HALLUCINATION';
      });
    } catch (e) {
      if (!mounted) return;

      // Check for 429 or similar status codes in the error message if possible
      if (e.toString().contains('429')) {
        setState(() {
          _isRateLimited = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSupportSelected(GroundingSupport? support) {
    setState(() {
      _activeSupport = support;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // appBar removed for sidebar-only navigation
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify the truth with Gemini AI',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste news text or claim here...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFD4AF37), width: 1),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      'Verify Claim',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            if (_isHydratingDemo)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                ),
              ),
            if (_isRateLimited) _buildRateLimitBanner(),
            if (_isRecoveringFromHallucination) _buildHallucinationBanner(),
            if (DemoManager.isDemoMode) _buildDemoBanner(),
            if (_result != null &&
                !_isRateLimited &&
                !_isRecoveringFromHallucination)
              _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "SYSTEM DEMO: PRE-LOADED FORENSIC DATA",
            style: GoogleFonts.outfit(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final bool isReal = _result!.verdict == 'REAL';
    final Color accentColor =
        isReal ? const Color(0xFFD4AF37) : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: isReal
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ]
            : [],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isReal ? 'VERIFIED REAL' : 'POTENTIAL MISINFORMATION',
                style: GoogleFonts.outfit(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(
                key: _globalRingKey,
                height: 80,
                width: 80,
                child: ConfidenceGauge(
                  score: _activeSupport != null
                      ? (_result!.reliabilityMetrics?.segments
                              .firstWhere(
                                  (s) => s.text == _activeSupport!.segment.text,
                                  orElse: () => SegmentAudit(
                                      text: '',
                                      sources: [],
                                      topSourceScore: 0.0,
                                      topSourceDomain: 'N/A'))
                              .topSourceScore ??
                          _result!.confidenceScore)
                      : (_result!.reliabilityMetrics?.reliabilityScore ??
                          _result!.confidenceScore),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Analysis',
            style: GoogleFonts.outfit(
              color: Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // --- Interactive Grounding Text ---
          VeriscanInteractiveText(
            key: _analysisKey,
            analysisText: _result!.analysis,
            groundingSupports: _result!.groundingSupports,
            groundingCitations: _result!.groundingCitations,
            scannedSources: _result!.scannedSources,
            attachments: const [],
            activeSupport: _activeSupport,
            onSupportSelected: _handleSupportSelected,
            reliabilityMetrics: _result!.reliabilityMetrics,
            evidenceTrayKey: _evidenceTrayKey,
            firstSegmentKey: _firstSegmentKey,
          ),
          // ----------------------------------

          // Removed Key Findings Section
        ],
      ),
    );
  }

  Widget _buildRateLimitBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM OVERLOADED',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VeriScan engines are at capacity. Retrying forensic analysis...',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHallucinationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM OVERLOADED',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI Hallucination detected. VeriScan is re-validating the evidence for accuracy...',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
