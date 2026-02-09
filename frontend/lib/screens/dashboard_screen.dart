import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fact_check_service.dart';
import '../widgets/confidence_gauge.dart';
import '../widgets/evidence_card.dart';
import '../widgets/input_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FactCheckService _service = FactCheckService();
  FactCheckResult? _result;
  bool _isLoading = false;

  Future<void> _handleAnalysis(
      String? text, String? url, PlatformFile? image) async {
    setState(() {
      _isLoading = true;

      _result = null;
    });

    try {
      final result = await _service.analyzeNews(
        text: text,
        url: url,
        imageBytes: image?.bytes, // This works for web and generic byte access
        imageFilename: image?.name,
      );

      setState(() {
        _result = result;
      });
    } catch (e) {
      setState(() {
        // _errorMessage = e.toString().replaceAll('Exception: ', '');
        debugPrint('Error: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          // Sidebar (Mock)
          Container(
            width: 80,
            color: Colors.black,
            child: Column(
              children: [
                SizedBox(height: 30),
                Icon(Icons.shield_outlined, color: Color(0xFFD4AF37), size: 40),
                SizedBox(height: 40),
                _SidebarItem(icon: Icons.dashboard, isActive: true),
                _SidebarItem(icon: Icons.history, isActive: false),
                _SidebarItem(icon: Icons.settings, isActive: false),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VERISCAN DASHBOARD',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          Text(
                            'Multimodal Forensic Analysis Engine',
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      _StatusBadge(),
                    ],
                  ),

                  SizedBox(height: 30),

                  // Bento Grid
                  Expanded(
                    child: SingleChildScrollView(
                      child: StaggeredGrid.count(
                        crossAxisCount: 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          // 1. Input Zone (Takes 2 Columns)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 2,
                            child: _BentoCard(
                              title: "INPUT DATA",
                              child: InputSection(
                                onAnalyze: _handleAnalysis,
                                isLoading: _isLoading,
                              ),
                            ),
                          ),

                          // 2. Confidence Gauge (Takes 1 Column)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _BentoCard(
                              title: "VERACITY SCORE",
                              child: _result == null
                                  ? Center(
                                      child: Text("Waiting for analysis...",
                                          style:
                                              TextStyle(color: Colors.white24)))
                                  : ConfidenceGauge(
                                      score: _result!.confidenceScore),
                            ),
                          ),

                          // 3. Verdict/Summary (Takes 1 Column)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 1,
                            mainAxisCellCount: 1,
                            child: _BentoCard(
                              title: "VERDICT",
                              child: _result == null
                                  ? Center(
                                      child: Text("--",
                                          style: TextStyle(
                                              color: Colors.white24,
                                              fontSize: 40)))
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _result!.isValid ? "REAL" : "FAKE",
                                          style: GoogleFonts.outfit(
                                            color: _result!.isValid
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFE53935),
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (_result!.keyFindings.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              _result!.keyFindings.first,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),

                          // 4. Analysis Text (Takes 2 Columns, below Gauge/Verdict)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 1, // Adjusted height
                            child: _BentoCard(
                              title: "FORENSIC ANALYSIS",
                              child: _result == null
                                  ? Center(
                                      child: Icon(Icons.analytics_outlined,
                                          color: Colors.white12, size: 40))
                                  : SingleChildScrollView(
                                      child: Text(
                                        _result!.analysis,
                                        style: GoogleFonts.outfit(
                                            color: Colors.white70, height: 1.5),
                                      ),
                                    ),
                            ),
                          ),

                          // 5. Evidence (Takes 2 Columns, 2 Rows - Side Panel logic usually, but here stacked)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 4,
                            mainAxisCellCount: 2,
                            child: _BentoCard(
                              title: "GROUNDING EVIDENCE",
                              child: _result == null
                                  ? Center(
                                      child: Text("No evidence loaded.",
                                          style:
                                              TextStyle(color: Colors.white24)))
                                  : ListView.builder(
                                      itemCount:
                                          _result!.groundingCitations.length,
                                      itemBuilder: (context, index) {
                                        final citation =
                                            _result!.groundingCitations[index];
                                        return EvidenceCard(
                                          title: citation['title'] ?? 'Source',
                                          snippet: citation['snippet'] ?? '',
                                          url: citation['url'] ?? '',
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
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

class _BentoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _BentoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              color: const Color(0xFFD4AF37),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;

  const _SidebarItem({required this.icon, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5))
            : null,
      ),
      child: Icon(
        icon,
        color: isActive ? const Color(0xFFD4AF37) : Colors.white24,
        size: 24,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Text(
            'SYSTEM ONLINE',
            style: GoogleFonts.outfit(
              color: const Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
