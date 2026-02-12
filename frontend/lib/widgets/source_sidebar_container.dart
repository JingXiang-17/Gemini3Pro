import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import 'evidence_card.dart';

class SourceSidebarContainer extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<GroundingCitation> citations;
  final List<int> activeIndices;
  final Function(int) onCitationSelected;
  final ScrollController scrollController;

  const SourceSidebarContainer({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.citations,
    this.activeIndices = const [],
    required this.onCitationSelected,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
      width: isExpanded ? 350 : 60,
      color: Colors.black,
      child: Column(
        children: [
          // Header / Toggle
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: isExpanded ? Alignment.centerRight : Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: IconButton(
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_double_arrow_left
                    : Icons.keyboard_double_arrow_right,
                color: const Color(0xFFD4AF37),
              ),
              onPressed: onToggle,
            ),
          ),
          // Content
          Expanded(
            child: isExpanded
                ? AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                    opacity: isExpanded ? 1.0 : 0.0,
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: citations.length,
                      itemBuilder: (context, index) {
                        final citation = citations[index];
                        final isActive = activeIndices.contains(index);
                        return GestureDetector(
                          onTap: () => onCitationSelected(index),
                          child: EvidenceCard(
                            title: citation.title,
                            snippet: citation.snippet,
                            url: citation.url,
                            isActive: isActive,
                          ),
                        );
                      },
                    ),
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
}
