import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/community_models.dart';
import '../services/community_service.dart';
import '../widgets/discussion_modal.dart';
import '../widgets/unified_sidebar.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _searchController = TextEditingController();

  List<ClaimSummary> _claims = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _loadTopClaims();
  }

  Future<void> _loadTopClaims() async {
    setState(() {
      _isLoading = true;
      _notFound = false;
    });

    try {
      final claims = await _communityService.getTopClaims(limit: 5);
      if (mounted) {
        setState(() {
          _claims = claims;
          _isLoading = false;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadTopClaims();
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _notFound = false;
    });

    try {
      final claims = await _communityService.searchClaims(query);
      if (mounted) {
        setState(() {
          _claims = claims;
          _isLoading = false;
          _notFound = claims.isEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          const UnifiedSidebar(activeIndex: 2),
          Expanded(
            child: Column(
              children: [
                // Custom Header (replacing AppBar)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  color: Colors.black,
                  child: Row(
                    children: [
                      Text(
                        'COMMUNITY',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _handleSearch,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search Community Records',
                      hintStyle: GoogleFonts.outfit(color: Colors.white38),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFFD4AF37)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                _loadTopClaims();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD4AF37),
        ),
      );
    }

    if (_notFound) {
      return _buildNotFoundState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSearching ? 'SEARCH RESULTS' : 'TOP 5 MOST VOTED CLAIMS',
            style: GoogleFonts.outfit(
              color: const Color(0xFFD4AF37),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return _buildGrid();
              } else {
                return _buildList();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _claims.map((claim) => _buildClaimCard(claim, true)).toList(),
    );
  }

  Widget _buildList() {
    return Column(
      children: _claims
          .map((claim) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildClaimCard(claim, false),
              ))
          .toList(),
    );
  }

  Widget _buildClaimCard(ClaimSummary claim, bool isGrid) {
    final isTrue = claim.trustScore >= 50;
    final scoreColor = isTrue ? Colors.green : Colors.red;

    return Container(
      width: isGrid ? 280 : double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trust Score Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${claim.trustScore.toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    color: scoreColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isTrue ? 'TRUE' : 'FALSE',
                  style: GoogleFonts.outfit(
                    color: scoreColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Claim Text
          Text(
            claim.claimText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // Votes Count
          Text(
            '${claim.voteCount} votes',
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          // View Discussion Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                debugPrint(
                    '🔍 Opening discussion for claim ID: ${claim.claimId}');
                showDialog(
                  context: context,
                  builder: (BuildContext context) => DiscussionModal(
                    claimId: claim.claimId,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD4AF37),
                side: const BorderSide(color: Color(0xFFD4AF37)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'View Discussion',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'NOT FOUND IN COMMUNITY',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFFD4AF37),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This claim hasn\'t been verified by the community yet. Would you like to verify it?',
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
              child: ElevatedButton.icon(
                onPressed: _navigateToMain,
                icon: const Icon(Icons.upload_file, size: 20),
                label: Text(
                  'Go to Main Upload',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
