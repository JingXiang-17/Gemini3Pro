import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/community_models.dart';
import '../services/community_service.dart';

class CommunityVoteBox extends StatefulWidget {
  final String? claimText;
  final String? aiVerdict;

  const CommunityVoteBox({
    super.key,
    this.claimText,
    this.aiVerdict,
  });

  @override
  State<CommunityVoteBox> createState() => _CommunityVoteBoxState();
}

class _CommunityVoteBoxState extends State<CommunityVoteBox> {
  final CommunityService _communityService = CommunityService();
  CommunityClaimData? _claimData;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.claimText != null) {
      _loadClaimData();
    }
  }

  @override
  void didUpdateWidget(CommunityVoteBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.claimText != oldWidget.claimText && widget.claimText != null) {
      _loadClaimData();
    }
  }

  Future<void> _loadClaimData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final data = await _communityService.getClaimData(widget.claimText!);
      if (mounted) {
        setState(() {
          _claimData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePostToCommunity() async {
    if (widget.claimText == null || widget.aiVerdict == null) return;

    setState(() => _isLoading = true);

    try {
      await _communityService.postClaim(widget.claimText!, widget.aiVerdict!);
      // Reload claim data
      await _loadClaimData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post claim: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSupportVerdict() async {
    if (_claimData?.claimId == null) return;

    // Demo user - in production, get from authentication
    const userId = 'demo_user';
    final vote = widget.aiVerdict == 'REAL';

    setState(() => _isLoading = true);

    try {
      final response = await _communityService.submitVote(
        _claimData!.claimId!,
        userId,
        vote,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: response.success ? Colors.green : Colors.orange,
          ),
        );

        // Reload claim data
        await _loadClaimData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.claimText == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(
            'No claim to analyze',
            style: GoogleFonts.outfit(
              color: Colors.white24,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD4AF37),
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Status A: New Claim (Not in community database)
    if (_claimData == null || !_claimData!.exists) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMMUNITY VOTE',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.groups_outlined,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No human data yet.',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask the community to verify.',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handlePostToCommunity,
                icon: const Icon(Icons.send, size: 18),
                label: Text(
                  'Post to Community',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Status B: Active Claim (Exists in community database)
    final trustScore = _claimData!.trustScore;
    final voteCount = _claimData!.voteCount;
    final isTrue = trustScore >= 50;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMUNITY VOTE',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Community Trust Meter',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Trust Score Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (isTrue ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isTrue ? Colors.green : Colors.red).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${trustScore.toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    color: isTrue ? Colors.green : Colors.red,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isTrue ? 'TRUE' : 'FALSE',
                  style: GoogleFonts.outfit(
                    color: isTrue ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$voteCount votes',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleSupportVerdict,
              icon: const Icon(Icons.thumb_up, size: 18),
              label: Text(
                'Support this Verdict',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
