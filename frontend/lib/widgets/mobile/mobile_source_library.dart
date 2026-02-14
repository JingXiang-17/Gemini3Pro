import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/grounding_models.dart';
import '../source_tile.dart';

class MobileSourceLibrary extends StatefulWidget {
  final List<GroundingCitation> citations;
  final List<SourceAttachment> uploadedAttachments;
  final Function(int) onCitationSelected;
  final Function(String) onDeleteAttachment;

  const MobileSourceLibrary({
    super.key,
    required this.citations,
    required this.uploadedAttachments,
    required this.onCitationSelected,
    required this.onDeleteAttachment,
  });

  @override
  State<MobileSourceLibrary> createState() => _MobileSourceLibraryState();
}

class _MobileSourceLibraryState extends State<MobileSourceLibrary> {
  bool _showEvidence = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Segmented Control
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _buildToggleItem("Evidence", _showEvidence),
                _buildToggleItem("Uploaded", !_showEvidence),
              ],
            ),
          ),
        ),
        // Active List
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showEvidence ? _buildEvidenceList() : _buildUploadedList(),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showEvidence = label == "Evidence"),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.black : Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceList() {
    if (widget.citations.isEmpty) {
      return Center(
        child: Text(
          "No grounding evidence found.",
          style: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
        ),
      );
    }

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
      key: const ValueKey("evidence_list"),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: uniqueCitations.length,
      itemBuilder: (context, index) {
        final citation = uniqueCitations[index];
        final key = "${citation.title}|${citation.url}";
        final count = sourceCounts[key] ?? 1;
        final originalIndex = firstOccurrenceIndex[key] ?? 0;

        return SourceTile(
          title: citation.title,
          url: citation.url,
          attachments: widget.uploadedAttachments,
          status: citation.status,
          count: count,
          onTap: () => widget.onCitationSelected(originalIndex),
        );
      },
    );
  }

  Widget _buildUploadedList() {
    if (widget.uploadedAttachments.isEmpty) {
      return Center(
        child: Text(
          "No files uploaded.",
          style: GoogleFonts.outfit(color: Colors.white24, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey("uploaded_list"),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.uploadedAttachments.length,
      itemBuilder: (context, index) {
        final attachment = widget.uploadedAttachments[index];
        return SourceTile(
          title: attachment.title,
          url: attachment.url ?? "",
          attachments: widget.uploadedAttachments,
          onDelete: () => widget.onDeleteAttachment(attachment.id),
        );
      },
    );
  }
}
