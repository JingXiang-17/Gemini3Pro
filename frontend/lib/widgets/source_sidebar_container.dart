import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import 'source_tile.dart';

class SourceSidebarContainer extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<GroundingCitation> citations;
  final List<SourceAttachment> uploadedAttachments;
  final List<int> activeIndices;
  final Function(int) onCitationSelected;
  final Function(String) onDeleteAttachment;
  final ScrollController scrollController;

  const SourceSidebarContainer({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.citations,
    required this.uploadedAttachments,
    this.activeIndices = const [],
    required this.onCitationSelected,
    required this.onDeleteAttachment,
    required this.scrollController,
  });

  @override
  State<SourceSidebarContainer> createState() => _SourceSidebarContainerState();
}

class _SourceSidebarContainerState extends State<SourceSidebarContainer> {
  bool _showEvidence = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
      width: widget.isExpanded ? 350 : 60,
      color: Colors.black,
      child: Column(
        children: [
          // Header / Toggle
          Container(
            height: 60,
            padding:
                EdgeInsets.symmetric(horizontal: widget.isExpanded ? 16 : 0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: widget.isExpanded
                    ? 318
                    : 60, // Match width to prevent icon clipping
                child: Row(
                  mainAxisAlignment: widget.isExpanded
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    if (widget.isExpanded) ...[
                      _buildTabSwitcher(),
                    ],
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        widget.isExpanded
                            ? Icons.keyboard_double_arrow_left
                            : Icons.keyboard_double_arrow_right,
                        color: const Color(0xFFD4AF37),
                        size: 20,
                      ),
                      onPressed: widget.onToggle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: widget.isExpanded
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showEvidence
                        ? _buildEvidenceList()
                        : _buildUploadedList(),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 20),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          "SOURCE MATERIAL",
                          style: GoogleFonts.outfit(
                            color: Colors.white24,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
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

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton("Uploaded", !_showEvidence),
          _buildTabButton("Evidence", _showEvidence),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _showEvidence = label == "Evidence"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.black : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceList() {
    final Map<String, int> sourceCounts = {};
    final List<GroundingCitation> uniqueCitations = [];
    final Map<String, int> firstOccurrenceIndex = {};

    for (int i = 0; i < widget.citations.length; i++) {
      final citation = widget.citations[i];
      final key = "${citation.title}|${citation.url}";
      if (!sourceCounts.containsKey(key)) {
        sourceCounts[key] = 1;
        uniqueCitations.add(citation);
        firstOccurrenceIndex[key] = i;
      } else {
        sourceCounts[key] = sourceCounts[key]! + 1;
      }
    }

    return ListView.builder(
      key: const ValueKey("evidence"),
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: uniqueCitations.length,
      itemBuilder: (context, index) {
        final citation = uniqueCitations[index];
        final key = "${citation.title}|${citation.url}";
        final count = sourceCounts[key] ?? 1;
        final originalIndex = firstOccurrenceIndex[key] ?? 0;
        final isActive = widget.activeIndices.contains(originalIndex);

        return SourceTile(
          title: citation.title,
          url: citation.url,
          attachments: widget.uploadedAttachments,
          status: citation.status,
          count: count,
          isActive: isActive,
          onTap: () => widget.onCitationSelected(originalIndex),
        );
      },
    );
  }

  Widget _buildUploadedList() {
    return ListView.builder(
      key: const ValueKey("uploaded"),
      padding: const EdgeInsets.all(16),
      itemCount: widget.uploadedAttachments.length,
      itemBuilder: (context, index) {
        final attachment = widget.uploadedAttachments[index];
        return Hero(
          tag: 'attachment_${attachment.id}',
          child: Material(
            color: Colors.transparent,
            child: SourceTile(
              title: attachment.title,
              url: attachment.url ?? "",
              attachments: widget.uploadedAttachments,
              isActive: false,
              onDelete: () => widget.onDeleteAttachment(attachment.id),
            ),
          ),
        );
      },
    );
  }
}
