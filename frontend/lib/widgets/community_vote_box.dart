import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/community_models.dart';
import '../screens/community_screen.dart';
import '../services/community_service.dart';

class CommunityVoteBox extends StatefulWidget {
  final String? claimText;
  final String? aiVerdict;
  final String? userEmail;

  const CommunityVoteBox({
    super.key,
    this.claimText,
    this.aiVerdict,
    this.userEmail,
  });

  @override
  State<CommunityVoteBox> createState() => _CommunityVoteBoxState();
}

class _CommunityVoteBoxState extends State<CommunityVoteBox> {
  final CommunityService _communityService = CommunityService();
  CommunityClaimData? _claimData;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isSubmittingVote = false;
  String? _submissionStateMessage;

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

  String _resolveUserId() {
    // Generate anonymous user ID for each vote
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 100000).toString().padLeft(5, '0');
    return 'anonymous_$random';
  }

  Future<bool> _submitCommunityVote({
    required String selectedVerdict,
    required String notes,
  }) async {
    if (widget.claimText == null || widget.aiVerdict == null) return false;

    setState(() {
      _isSubmittingVote = true;
      _submissionStateMessage = 'Loading community update...';
    });

    final userId = _resolveUserId();

    try {
      String claimId = _claimData?.claimId ?? '';

      if (claimId.isEmpty) {
        final postResponse =
            await _communityService.postClaim(widget.claimText!, widget.aiVerdict!);
        claimId = postResponse.claimId;
      }

      final response = await _communityService.submitVote(
        claimId: claimId,
        userId: userId,
        userVerdict: selectedVerdict,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      );

      if (!response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isSubmittingVote = false;
            _submissionStateMessage = null;
          });
        }
        return false;
      }

      await _loadClaimData();

      if (mounted) {
        setState(() {
          _isSubmittingVote = false;
          _submissionStateMessage = 'Thank you for voting.';
        });
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmittingVote = false;
          _submissionStateMessage = null;
        });
      }

      return false;
    }
  }

  Future<void> _openSubmissionModal() async {
    if (widget.claimText == null || widget.aiVerdict == null) return;

    String selectedVerdict = 'Legit';
    bool isModalSubmitting = false;
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFC107),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit to Community Verification',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFFC107),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your Verdict',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ['Legit', 'Suspect', 'Fake'].map((option) {
                        final isSelected = selectedVerdict == option;
                        return ChoiceChip(
                          label: Text(
                            option,
                            style: GoogleFonts.outfit(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: isModalSubmitting
                              ? null
                              : (_) {
                                  setModalState(() {
                                    selectedVerdict = option;
                                  });
                                },
                          selectedColor: const Color(0xFFFFC107),
                          backgroundColor: Colors.black,
                          side: const BorderSide(color: Color(0xFFFFC107)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Optional Notes/Evidence',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      enabled: !isModalSubmitting,
                      maxLines: 4,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'I saw this on a local news site',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFFC107)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFFC107),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isModalSubmitting
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isModalSubmitting
                              ? null
                              : () async {
                                  setModalState(() => isModalSubmitting = true);

                                  final success = await _submitCommunityVote(
                                    selectedVerdict: selectedVerdict,
                                    notes: notesController.text,
                                  );

                                  if (!mounted) return;

                                  if (success) {
                                    Navigator.of(dialogContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Vote posted to community.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const CommunityScreen(),
                                      ),
                                    );
                                  } else {
                                    setModalState(() => isModalSubmitting = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: isModalSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  'Post to Community',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    notesController.dispose();
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

    // Status A: Not yet verified (no data from community)
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
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isSubmittingVote ? null : _openSubmissionModal,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFFFFC107),
              ),
              child: Text(
                'Ask the community to verify',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFFC107),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_submissionStateMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _submissionStateMessage!,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
            if (_isSubmittingVote) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: Color(0xFFD4AF37),
                backgroundColor: Colors.white10,
                minHeight: 3,
              ),
            ],
            const SizedBox(height: 8),
            if (_hasError)
              Text(
                'Unable to fetch latest community stats right now.',
                style: GoogleFonts.outfit(
                  color: Colors.redAccent,
                  fontSize: 11,
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
              onPressed: _isSubmittingVote ? null : _openSubmissionModal,
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
          if (_submissionStateMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _submissionStateMessage!,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
