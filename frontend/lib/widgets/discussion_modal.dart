import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/discussion_models.dart';
import '../services/community_service.dart';

class DiscussionModal extends StatefulWidget {
  final String claimId;

  const DiscussionModal({super.key, required this.claimId});

  @override
  State<DiscussionModal> createState() => _DiscussionModalState();
}

class _DiscussionModalState extends State<DiscussionModal> {
  final CommunityService _service = CommunityService();
  final TextEditingController _notesController = TextEditingController();
  
  ClaimDiscussion? _discussion;
  bool _isLoading = true;
  String? _error;
  String _selectedVerdict = 'Legit';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDiscussion();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscussion() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final discussion = await _service.getClaimDiscussion(widget.claimId);
      if (mounted) {
        setState(() {
          _discussion = discussion;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load discussion: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitPerspective() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your perspective before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Generate anonymous user ID
      final userId = 'anonymous_${DateTime.now().millisecondsSinceEpoch % 100000}';
      
      await _service.submitVote(
        claimId: widget.claimId,
        userId: userId,
        userVerdict: _selectedVerdict,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        _notesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your perspective has been added!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload discussion
        await _loadDiscussion();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 800,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forum, color: Color(0xFFD4AF37), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Community Discussion',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFD4AF37),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildDiscussionContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscussionContent() {
    if (_discussion == null) return const SizedBox();

    final isTrue = _discussion!.trustScore >= 50;
    final scoreColor = isTrue ? Colors.green : Colors.red;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Claim Text
          Text(
            _discussion!.claimText,
            style: GoogleFonts.outfit(
              color: const Color(0xFFD4AF37),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 20),

          // Stats Row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // AI Verdict Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.smart_toy, size: 14, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    Text(
                      'AI: ${_discussion!.aiVerdict}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF4CAF50),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Community Score Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      'Community: ${_discussion!.trustScore.toStringAsFixed(0)}%',
                      style: GoogleFonts.outfit(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Human Insights Header
          Text(
            'HUMAN INSIGHTS (${_discussion!.votes.length})',
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Comments/Notes List
          if (_discussion!.votes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No insights yet. Be the first to add your perspective!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ..._discussion!.votes.map((vote) => _buildCommentBubble(vote)),

          const SizedBox(height: 24),

          // Add Your Perspective Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADD YOUR PERSPECTIVE',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFD4AF37),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Verdict Selection
                Wrap(
                  spacing: 10,
                  children: ['Legit', 'Suspect', 'Fake'].map((verdict) {
                    final isSelected = _selectedVerdict == verdict;
                    return ChoiceChip(
                      label: Text(
                        verdict,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: _isSubmitting ? null : (_) {
                        setState(() => _selectedVerdict = verdict);
                      },
                      selectedColor: const Color(0xFFD4AF37),
                      backgroundColor: Colors.black,
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFD4AF37)
                            : Colors.white24,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // Notes TextField
                TextField(
                  controller: _notesController,
                  enabled: !_isSubmitting,
                  maxLines: 3,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Share your evidence or reasoning...',
                    hintStyle: GoogleFonts.outfit(
                      color: Colors.white30,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFD4AF37),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitPerspective,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Submit Perspective',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
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

  Widget _buildCommentBubble(VoteEntry vote) {
    final verdictColor = vote.userVerdict == 'LEGIT'
        ? Colors.green
        : (vote.userVerdict == 'FAKE' ? Colors.red : Colors.orange);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: verdictColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Verdict + Timestamp
          Row(
            children: [
              // Verdict Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  vote.userVerdict,
                  style: GoogleFonts.outfit(
                    color: verdictColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // User (anonymized)
              Text(
                vote.userId.startsWith('anonymous') ? 'Anonymous' : vote.userId,
                style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              // Timestamp
              Text(
                timeago.format(vote.timestamp, locale: 'en_short'),
                style: GoogleFonts.outfit(
                  color: Colors.white24,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          // Notes/Evidence
          if (vote.notes != null && vote.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              vote.notes!,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
