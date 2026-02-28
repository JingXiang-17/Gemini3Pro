import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import '../services/fact_check_service.dart';
import '../widgets/glass_action_bar.dart';
import '../widgets/source_sidebar_container.dart';
import '../widgets/verdict_pane.dart';
import '../widgets/veriscan_interactive_text.dart';
import '../widgets/mobile/mobile_sticky_header.dart';
import '../widgets/mobile/mobile_source_library.dart';
import '../widgets/juicy_button.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../widgets/unified_sidebar.dart';
import '../utils/demo_manager.dart';
import '../services/demo_service.dart';
import '../services/onboarding_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final FactCheckService _service = FactCheckService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _sidebarScrollController = ScrollController();
  final GlobalKey _sidebarKey = GlobalKey();
  final GlobalKey _sourcesTabKey = GlobalKey();

  // Tutorial Keys
  final GlobalKey _evidenceTrayKey = GlobalKey();
  final GlobalKey _globalRingKey = GlobalKey();
  final GlobalKey _firstSegmentKey = GlobalKey();
  final GlobalKey _scannedRingKey = GlobalKey();
  final OnboardingService _onboardingService = OnboardingService();

  AnalysisResponse? _result;
  bool _isLoading = false;
  bool _isHydratingDemo = false; // New flag for demo loading
  bool _hasError = false;
  bool _isSidebarExpanded = true;
  int _mobileSelectedIndex = 0;

  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();

    // 1. Listen to incoming shared media WHILE THE APP IS OPEN
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) _handleSharedMedia(value); // Pass the whole list
    }, onError: (err) => debugPrint("Shared Intent Error: $err"));

    // 2. Get the initial shared media if the app was CLOSED (Cold Start)
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) _handleSharedMedia(value); // Pass the whole list
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel(); // Prevent memory leaks
    _inputController.dispose();
    _sidebarScrollController.dispose();
    DemoManager.isDemoMode = false; // Reset demo mode on exit
    super.dispose();
  }

  // Attachments State
  final List<SourceAttachment> _pendingAttachments = [];
  final List<SourceAttachment> _migratedAttachments = [];
  final Map<String, GlobalKey> _chipKeys = {};

  List<int> _activeCitationIndices = [];
  GroundingSupport? _activeSupport;

  // ===========================================================================
  //  LOGIC
  // ===========================================================================

  Future<void> _handleSharedMedia(List<SharedMediaFile> mediaList) async {
    bool hasData = false;

    for (int i = 0; i < mediaList.length; i++) {
      final media = mediaList[i];

      // CASE A: Shared Text or URLs
      if (media.type == SharedMediaType.text ||
          media.type == SharedMediaType.url) {
        setState(() {
          final currentText = _inputController.text;
          _inputController.text =
              currentText.isEmpty ? media.path : "$currentText\n${media.path}";
        });
        hasData = true;
      }
      // CASE B: Shared Images or Files
      else {
        // 1. Read the actual physical file from the Android Share cache
        final file = File(media.path);
        final bytes = await file.readAsBytes(); // Get the raw image data

        // 2. Package it perfectly for your FactCheckService
        final platformFile = PlatformFile(
          name: media.path.split('/').last,
          size: bytes.length,
          bytes: bytes,
          path: media.path,
        );

        // 3. Attach the REAL file, not just the URL string
        final attachment = SourceAttachment(
          id: "${DateTime.now().millisecondsSinceEpoch}_$i",
          title: platformFile.name,
          type: media.type == SharedMediaType.image
              ? AttachmentType.image
              : AttachmentType.pdf,
          file: platformFile, // <--- THIS IS THE MAGIC FIX
        );

        _handleAddAttachment(attachment);
        hasData = true;
      }
    }

    // Automatically trigger analysis
    if (hasData) {
      _handleAnalysis();
    }
  }

  void _handleAddAttachment(SourceAttachment attachment) {
    setState(() {
      _pendingAttachments.add(attachment);
    });
  }

  void _handleRemoveAttachment(String id) {
    setState(() {
      _pendingAttachments.removeWhere((a) => a.id == id);
      _chipKeys.remove(id);
    });
  }

  void _handleDeleteMigratedAttachment(String id) {
    setState(() {
      _migratedAttachments.removeWhere((a) => a.id == id);
    });
  }

  Future<void> _handleAnalysis({bool isRetry = false}) async {
    final text = _inputController.text.trim();
    if (text.isEmpty &&
        _pendingAttachments.isEmpty &&
        _migratedAttachments.isEmpty) {
      return;
    }

    // Reset demo mode if starting real analysis
    DemoManager.isDemoMode = false;

    // 1. Start Migration Animation
    if (_pendingAttachments.isNotEmpty) {
      await _animateMigration();
    }

    setState(() {
      _isLoading = true;
      _isHydratingDemo = false; // Manual analysis is NOT demo hydration
      _hasError = false;
      _result = null;
      _activeSupport = null;
    });

    final allAttachments = [..._migratedAttachments, ..._pendingAttachments];
    final recentlyMigrated = List<SourceAttachment>.from(_pendingAttachments);

    try {
      final result = await _service.analyzeNews(
        text: text,
        attachments: allAttachments,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _migratedAttachments.addAll(recentlyMigrated);
          _pendingAttachments.clear();
          _chipKeys.clear();
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('ANALYSIS ERROR: $e');

      // Auto-retry once if it's the first attempt and it's a timeout/cold-start error
      if (!isRetry && mounted) {
        // Only retry for timeout errors or cold start indicators
        final errorString = e.toString().toLowerCase();
        final isRetryableError = e is TimeoutException ||
            errorString.contains('timeout') ||
            errorString.contains('warm') ||
            errorString.contains('cold start');

        if (isRetryableError) {
          debugPrint('Retrying after cold start...');
          await Future.delayed(const Duration(seconds: 2));

          // Check mounted again after delay
          if (mounted) {
            return _handleAnalysis(isRetry: true);
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDemoTrigger() async {
    setState(() {
      _isLoading = true;
      _isHydratingDemo = true; // Set demo hydration flag
      _hasError = false;
      _result = null;
      _activeSupport = null; // Reset selection state for demo
      _activeCitationIndices = [];
    });

    debugPrint("🔍 DEBUG: Starting Demo Trigger in DashboardScreen.");

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

          String errorMessage = "Forensic Asset load failed.";
          // This specific case (result == null) is treated as asset not found
          errorMessage = "Forensic Asset not found. Reverting to Live Mode.";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });

        // Launch Onboarding Tour immediately once mounted
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint(
                "🔍 DEBUG: Attempting to launch Onboarding Tour (Dashboard)...");
            _onboardingService.showDemoTour(
              context,
              firstSegmentKey: _firstSegmentKey,
              evidenceTrayKey: _evidenceTrayKey,
              globalRingKey: _sidebarKey,
              scannedRingKey: _scannedRingKey,
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
      }
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
          debugPrint("❌ DEBUG TYPE ERROR: $e");
        } else {
          errorMessage = "Forensic Asset not found. Reverting to Live Mode.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isHydratingDemo = false; // Reset demo hydration flag
        });
      }
    }
  }

  Widget _buildErrorRetryCard() {
    return Center(
      child: RepaintBoundary(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: Color(0xFFD4AF37),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "SYSTEM WARM-UP REQUIRED",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "The forensic engine is waking up. Please click below to re-submit your request.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: JuicyButton(
                  onTap: _handleAnalysis,
                  child: Container(
                    // Changed ElevatedButton to a Container to hold the style
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "RE-VERIFY CLAIM",
                      style: GoogleFonts.outfit(
                        color: Colors.black, // Make sure text stays black
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _animateMigration() async {
    final bool isMobile = MediaQuery.of(context).size.width <= 900;
    final List<SourceAttachment> attachments = List.from(_pendingAttachments);
    final List<OverlayEntry> entries = [];

    // Find target (Sidebar or Tab Icon) position
    final RenderObject? targetObject = isMobile
        ? _sourcesTabKey.currentContext?.findRenderObject()
        : _sidebarKey.currentContext?.findRenderObject();

    if (targetObject == null) return;
    final RenderBox targetBox = targetObject as RenderBox;
    final Offset targetOffset = targetBox.localToGlobal(Offset.zero) +
        (isMobile ? const Offset(12, 12) : const Offset(150, 40));

    for (final attachment in attachments) {
      final key = _chipKeys[attachment.id];
      if (key == null) continue;

      final RenderBox? chipBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (chipBox == null) continue;

      final Offset startOffset = chipBox.localToGlobal(Offset.zero);
      final Size blockSize = chipBox.size;

      final entry = OverlayEntry(
        builder: (context) {
          return _FlyingAttachment(
            startOffset: startOffset,
            endOffset: targetOffset,
            size: blockSize,
            attachment: attachment,
          );
        },
      );
      entries.add(entry);
      Overlay.of(context).insert(entry);
    }

    await Future.delayed(const Duration(milliseconds: 1000));

    for (final entry in entries) {
      entry.remove();
    }
  }

  void _handleSupportSelected(GroundingSupport? support) {
    setState(() {
      if (_activeSupport == support) {
        _activeSupport = null;
        _activeCitationIndices = [];
      } else {
        _activeSupport = support;
        _activeCitationIndices = support?.groundingChunkIndices ?? [];
        if (!_isSidebarExpanded) _isSidebarExpanded = true;
      }
    });
  }

  void _handleCitationSelected(int index) {
    setState(() {
      _activeCitationIndices = [index];
      _activeSupport = null;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  // ===========================================================================
  //  UI BRANCHING (UPDATED FOR GLOBAL MENU BUTTON)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // 1. Wrap in Scaffold to host the Drawer
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return _buildDesktopLayout(constraints);
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  // --- DESKTOP LAYOUT (3-Pane) ---
  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final bool showSidebar = constraints.maxWidth > 1100;
    final bool showVerdictPane = constraints.maxWidth > 1000;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // NO AppBar here (handled by parent Stack)
      // NO Drawer here (handled by parent Scaffold)
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const UnifiedSidebar(activeIndex: 1),
          // Sidebar (Responsive)
          if (showSidebar || _isSidebarExpanded)
            Flexible(
              flex: 0,
              child: SourceSidebarContainer(
                key: _sidebarKey,
                isExpanded: _isSidebarExpanded,
                onToggle: _toggleSidebar,
                citations: _result?.groundingCitations ?? [],
                scannedSources: _result?.scannedSources ?? [],
                uploadedAttachments: _migratedAttachments,
                activeIndices: _activeCitationIndices,
                reliabilityMetrics: _result?.reliabilityMetrics,
                activeSupport: _activeSupport,
                onCitationSelected: _handleCitationSelected,
                onDeleteAttachment: _handleDeleteMigratedAttachment,
                scrollController: _sidebarScrollController,
                scannedRingKey: _scannedRingKey,
              ),
            ),
          // Analysis Hub
          Expanded(
            flex: 20, // 2.0 Left Lane
            child: Container(
              color: const Color(0xFF121212),
              child: Column(
                children: [
                  // Analysis Content
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_activeSupport != null) {
                          setState(() {
                            _activeSupport = null;
                            _activeCitationIndices = [];
                          });
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "FORENSIC ANALYSIS",
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFD4AF37),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                if (DemoManager.isDemoMode)
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.amber.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.amber
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          "SYSTEM DEMO: PRE-LOADED FORENSIC DATA",
                                          style: GoogleFonts.outfit(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Container(
                                decoration: DemoManager.isDemoMode &&
                                        _result != null
                                    ? BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber
                                                .withValues(alpha: 0.05),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      )
                                    : null,
                                child: _isHydratingDemo
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFD4AF37),
                                        ),
                                      )
                                    : (_hasError && !DemoManager.isDemoMode
                                        ? _buildErrorRetryCard()
                                        : (_result == null
                                            ? _buildForensicHubGrid()
                                            : SingleChildScrollView(
                                                child: VeriscanInteractiveText(
                                                  analysisText:
                                                      _result!.analysis,
                                                  groundingSupports: _result!
                                                      .groundingSupports,
                                                  groundingCitations: _result!
                                                      .groundingCitations,
                                                  scannedSources:
                                                      _result!.scannedSources,
                                                  attachments:
                                                      _migratedAttachments,
                                                  activeSupport: _activeSupport,
                                                  reliabilityMetrics: _result
                                                      ?.reliabilityMetrics,
                                                  onSupportSelected:
                                                      _handleSupportSelected,
                                                  firstSegmentKey:
                                                      _firstSegmentKey,
                                                  evidenceTrayKey:
                                                      _evidenceTrayKey,
                                                ),
                                              ))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Action Bar
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      child: GlassActionBar(
                        controller: _inputController,
                        onAnalyze: _handleAnalysis,
                        attachments: _pendingAttachments,
                        chipKeys: _chipKeys,
                        onAddAttachment: _handleAddAttachment,
                        onRemoveAttachment: _handleRemoveAttachment,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Verdict Pane (Responsive)
          if (showVerdictPane)
            Expanded(
              flex: 12, // 1.2 Right Lane
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: VerdictPane(result: _result, gaugeKey: _globalRingKey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- MOBILE LAYOUT (Unchanged logic, just structure) ---
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Main Scrollable Content
          Expanded(
            child: IndexedStack(
              index: _mobileSelectedIndex,
              children: [_buildMobileReportView(), _buildMobileSourcesView()],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: GlassActionBar(
              controller: _inputController,
              onAnalyze: _handleAnalysis,
              attachments: _pendingAttachments,
              chipKeys: _chipKeys,
              onAddAttachment: _handleAddAttachment,
              onRemoveAttachment: _handleRemoveAttachment,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: BottomNavigationBar(
          onTap: (index) => setState(() => _mobileSelectedIndex = index),
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: Colors.white24,
          currentIndex: _mobileSelectedIndex,
          selectedLabelStyle: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              label: 'Report',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_outlined, key: _sourcesTabKey),
              label: 'Sources',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileReportView() {
    return CustomScrollView(
      slivers: [
        // Sticky Header Row - Always visible with placeholders
        SliverPersistentHeader(
          pinned: true,
          delegate: MobileStickyHeaderDelegate(result: _result),
        ),

        if (_hasError)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
              child: _buildErrorRetryCard(),
            ),
          )
        else if (_result == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
              child: _buildForensicHubGrid(),
            ),
          )
        else ...[
          // Forensic Analysis Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            sliver: SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () {
                  if (_activeSupport != null) {
                    setState(() {
                      _activeSupport = null;
                      _activeCitationIndices = [];
                    });
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FORENSIC ANALYSIS",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD4AF37),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      VeriscanInteractiveText(
                        analysisText: _result!.analysis,
                        groundingSupports: _result!.groundingSupports,
                        groundingCitations: _result!.groundingCitations,
                        scannedSources: _result!.scannedSources,
                        attachments: _migratedAttachments,
                        activeSupport: _activeSupport,
                        onSupportSelected: _handleSupportSelected,
                        firstSegmentKey: _firstSegmentKey,
                        evidenceTrayKey: _evidenceTrayKey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Removed Key Findings Section for Mobile
      ],
    );
  }

  Widget _buildForensicHubGrid() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.biotech_outlined,
                size: 48,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                "Awaiting Forensic Ingestion...",
                style: GoogleFonts.outfit(
                  color: const Color(0xFFE0E0E0),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "CAPABILITIES",
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Capabilities Grid Section
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _buildCapabilityItem(
                          Icons.verified_user_outlined, "Claims"),
                      const SizedBox(width: 12),
                      _buildCapabilityItem(Icons.image_search, "Media"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildCapabilityItem(
                          Icons.find_in_page_outlined, "Sources"),
                      const SizedBox(width: 12),
                      _buildCapabilityItem(Icons.history_edu, "Archives"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // THE DEMO TRIGGER
                  JuicyButton(
                    onTap: () {
                      DemoManager.isDemoMode = true;
                      _handleDemoTrigger();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.biotech,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "TRY FORENSIC DEMO",
                            style: GoogleFonts.outfit(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilityItem(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSourcesView() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: MobileSourceLibrary(
        citations: _result?.groundingCitations ?? [],
        uploadedAttachments: _migratedAttachments,
        onCitationSelected: _handleCitationSelected,
        onDeleteAttachment: _handleDeleteMigratedAttachment,
      ),
    );
  }
}

class _FlyingAttachment extends StatelessWidget {
  final Offset startOffset;
  final Offset endOffset;
  final Size size;
  final SourceAttachment attachment;

  const _FlyingAttachment({
    required this.startOffset,
    required this.endOffset,
    required this.size,
    required this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: startOffset, end: endOffset),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutCubic,
      builder: (context, Offset offset, Widget? child) {
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 1.0 -
                  (offset.dx - startOffset.dx).abs() /
                      (endOffset.dx - startOffset.dx)
                          .abs()
                          .clamp(1.0, 99999.0)
                          .toDouble() *
                      0.5,
              child: Container(
                width: size.width,
                height: size.height,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.black,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        attachment.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
