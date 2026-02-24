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
import '../widgets/veriscan_drawer.dart';
import '../widgets/global_menu_button.dart';
import '../widgets/juicy_button.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'community_screen.dart';

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

  AnalysisResponse? _result;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isSidebarExpanded = true;
  int _mobileSelectedIndex = 0;

  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();

    // 1. Listen to incoming shared media (files/text) WHILE THE APP IS OPEN
    // receive_sharing_intent exposes media streams; text shares arrive as
    // SharedMediaFile where `path` contains the text payload.
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      try {
        if (value.isNotEmpty) {
          final first = value.first;
          final sharedText = first.path;
          if (sharedText.isNotEmpty) {
            _handleSharedText(sharedText);
          }
        }
      } catch (e) {
        debugPrint('Shared Intent processing error: $e');
      }
    }, onError: (err) {
      debugPrint("Shared Intent Error: $err");
    });

    // 2. Get the initial shared media if the app was CLOSED (Cold Start)
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      try {
        if (value.isNotEmpty) {
          final first = value.first;
          final sharedText = first.path;
          if (sharedText.isNotEmpty) {
            _handleSharedText(sharedText);
          }
        }
      } catch (e) {
        debugPrint('Initial shared intent processing error: $e');
      }
    });
  }

  void _handleSharedText(String text) {
    setState(() {
      _inputController.text = text;
    });
    // Optional: Automatically trigger analysis when shared
    _handleAnalysis(); 
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel(); // Critical to prevent memory leaks
    _inputController.dispose();
    _sidebarScrollController.dispose();
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

    // 1. Start Migration Animation
    if (_pendingAttachments.isNotEmpty) {
      await _animateMigration();
    }

    setState(() {
      _isLoading = true;
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
              color: const Color(0xFFD4AF37).withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
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
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
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
                  child: Container( // Changed ElevatedButton to a Container to hold the style
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

      final entry = OverlayEntry(builder: (context) {
        return _FlyingAttachment(
          startOffset: startOffset,
          endOffset: targetOffset,
          size: blockSize,
          attachment: attachment,
        );
      });
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

    if (_result != null &&
        _activeCitationIndices.isNotEmpty &&
        _sidebarScrollController.hasClients) {
      final firstIndex = _activeCitationIndices.first;
      _sidebarScrollController.animateTo(
        firstIndex * 110.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
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
      drawer: const VeriscanDrawer(), // The Drawer lives here now
      body: Stack(
        children: [
          // 2. Main Content (Padded so button doesn't cover top-left content)
          Padding(
            padding: const EdgeInsets.only(top: 60.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return _buildDesktopLayout();
                } else {
                  return _buildMobileLayout();
                }
              },
            ),
          ),

          // 3. The Global Button (Floats on top of everything)
          Positioned(
            top: 0,
            left: 0,
            child: Builder(
              // Builder needed to find the Scaffold above
              builder: (innerContext) => GlobalMenuButton(
                onTap: () => Scaffold.of(innerContext).openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DESKTOP LAYOUT (Removed AppBar & Drawer) ---
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // NO AppBar here (handled by parent Stack)
      // NO Drawer here (handled by parent Scaffold)
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nav Rail
          Container(
            width: 80,
            color: Colors.black,
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Icon(Icons.shield_outlined, color: Color(0xFFD4AF37), size: 40),
                const SizedBox(height: 40),
                const _SidebarIcons(icon: Icons.dashboard, isActive: true),
                const _SidebarIcons(icon: Icons.history, isActive: false),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CommunityScreen(),
                      ),
                    );
                  },
                  child: const _SidebarIcons(icon: Icons.groups, isActive: false),
                ),
                const _SidebarIcons(icon: Icons.settings, isActive: false),
              ],
            ),
          ),
          // Sidebar
          Flexible(
            flex: 0,
            child: SourceSidebarContainer(
              key: _sidebarKey,
              isExpanded: _isSidebarExpanded,
              onToggle: _toggleSidebar,
              citations: _result?.groundingCitations ?? [],
              uploadedAttachments: _migratedAttachments,
              activeIndices: _activeCitationIndices,
              onCitationSelected: _handleCitationSelected,
              onDeleteAttachment: _handleDeleteMigratedAttachment,
              scrollController: _sidebarScrollController,
            ),
          ),
          // Analysis Hub
          Expanded(
            flex: 5,
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
                            Text("FORENSIC ANALYSIS",
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                )),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _hasError
                                  ? _buildErrorRetryCard()
                                  : (_result == null
                                      ? _buildForensicHubGrid()
                                      : SingleChildScrollView(
                                          child: VeriscanInteractiveText(
                                            analysisText: _result!.analysis,
                                            groundingSupports:
                                                _result!.groundingSupports,
                                            groundingCitations:
                                                _result!.groundingCitations,
                                            attachments: _migratedAttachments,
                                            activeSupport: _activeSupport,
                                            onSupportSelected:
                                                _handleSupportSelected,
                                          ),
                                        )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Action Bar
                  Padding(
                    padding: const EdgeInsets.all(20.0),
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
            ),
          ),
          // Verdict Pane
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border(
                  left:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: VerdictPane(result: _result),
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
              children: [
                _buildMobileReportView(),
                _buildMobileSourcesView(),
              ],
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
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: BottomNavigationBar(
          onTap: (index) => setState(() => _mobileSelectedIndex = index),
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: Colors.white24,
          currentIndex: _mobileSelectedIndex,
          selectedLabelStyle:
              GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
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
                      Text("FORENSIC ANALYSIS",
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFD4AF37),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          )),
                      const SizedBox(height: 16),
                      VeriscanInteractiveText(
                        analysisText: _result!.analysis,
                        groundingSupports: _result!.groundingSupports,
                        groundingCitations: _result!.groundingCitations,
                        attachments: _migratedAttachments,
                        activeSupport: _activeSupport,
                        onSupportSelected: _handleSupportSelected,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Key Findings Section (If available)
        if (_result != null && _result!.keyFindings.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
            sliver: SliverToBoxAdapter(
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
                    Text("KEY FINDINGS",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD4AF37),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        )),
                    const SizedBox(height: 12),
                    ..._result!.keyFindings.map((finding) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.check_circle_outline,
                                    size: 14, color: Color(0xFFD4AF37)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  finding,
                                  style: GoogleFonts.outfit(
                                      color: const Color(0xFFE0E0E0),
                                      fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildForensicHubGrid() {
    return Container(
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
          Icon(Icons.biotech_outlined,
              size: 48, color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
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
                  _buildCapabilityItem(Icons.verified_user_outlined, "Claims"),
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
            ],
          ),
        ],
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

class _SidebarIcons extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  const _SidebarIcons({required this.icon, required this.isActive});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Icon(
        icon,
        color: isActive ? const Color(0xFFD4AF37) : Colors.white24,
        size: 24,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.black, size: 16),
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
