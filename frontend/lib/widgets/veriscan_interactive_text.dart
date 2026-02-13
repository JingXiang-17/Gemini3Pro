import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/grounding_models.dart';
import '../utils/grounding_parser.dart';
import 'evidence_card.dart';

class VeriscanInteractiveText extends StatefulWidget {
  final String analysisText;
  final List<GroundingSupport> groundingSupports;
  final List<GroundingCitation> groundingCitations;
  final GroundingSupport? activeSupport;
  final Function(GroundingSupport?)? onSupportSelected;

  const VeriscanInteractiveText({
    super.key,
    required this.analysisText,
    required this.groundingSupports,
    required this.groundingCitations,
    this.activeSupport,
    this.onSupportSelected,
  });

  @override
  State<VeriscanInteractiveText> createState() =>
      _VeriscanInteractiveTextState();
}

class _VeriscanInteractiveTextState extends State<VeriscanInteractiveText> {
  static const double kFontSize = 15.0;
  static const double kStrutHeight = 2.0;
  static const Color kGold = Color(0xFFD4AF37);

  GroundingSupport? _hoveredSupport;

  @override
  Widget build(BuildContext context) {
    if (widget.analysisText.isEmpty) return const SizedBox();

    final chunks =
        GroundingParser.parse(widget.analysisText, widget.groundingSupports);
    final theme = Theme.of(context);

    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: kFontSize,
          height: 1.0,
        ) ??
        const TextStyle(fontSize: kFontSize, height: 1.0);

    const strutStyle = StrutStyle(
      fontSize: kFontSize,
      height: kStrutHeight,
      forceStrutHeight: true,
      leading: 0.5,
    );

    // Identify if we need to split the text to insert a card
    int activeChunkIndex = -1;
    if (widget.activeSupport != null) {
      activeChunkIndex = chunks.indexWhere((c) =>
          c.support != null &&
          c.support!.segment.startIndex ==
              widget.activeSupport!.segment.startIndex);
    }

    // Always split or treat as single block to keep AnimatedSwitcher in tree for transition
    final int splitIndex =
        activeChunkIndex != -1 ? activeChunkIndex + 1 : chunks.length;
    final beforeChunks = chunks.sublist(0, splitIndex);
    final afterChunks = chunks.sublist(splitIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRichTextBlock(beforeChunks, baseStyle, strutStyle),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (child, previousChildren) => Stack(
            alignment: Alignment.topLeft,
            children: [
              ...previousChildren,
              if (child != null) child,
            ],
          ),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: (activeChunkIndex != -1)
              ? Container(
                  key: ValueKey(widget.activeSupport!.segment.startIndex),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: _getReferencedCitations(widget.activeSupport!)
                        .map((citation) => EvidenceCard(
                              title: citation.title,
                              snippet: citation.snippet,
                              url: citation.url,
                              isActive: true,
                            ))
                        .toList(),
                  ),
                )
              : const SizedBox(key: ValueKey('empty_expansion')),
        ),
        if (afterChunks.isNotEmpty)
          _buildRichTextBlock(afterChunks, baseStyle, strutStyle),
      ],
    );
  }

  Widget _buildRichTextBlock(
      List<TextChunk> chunks, TextStyle baseStyle, StrutStyle strutStyle) {
    return RichText(
      strutStyle: strutStyle,
      text: TextSpan(
        style: baseStyle,
        children: chunks.expand((chunk) {
          if (chunk.type == ChunkType.plain) {
            return [TextSpan(text: chunk.text)];
          } else {
            final bool isSelected = widget.activeSupport != null &&
                chunk.support != null &&
                chunk.support!.segment.startIndex ==
                    widget.activeSupport!.segment.startIndex;

            final isHovered = _hoveredSupport == chunk.support;

            final bool shouldUnderline = isSelected || isHovered;

            final Color decorationColor = isSelected
                ? kGold
                : (isHovered
                    ? kGold.withValues(alpha: 0.4)
                    : Colors.transparent);

            final double decorationThickness = isSelected ? 3.0 : 1.0;
            final double lineHeight = isSelected ? 1.8 : 1.0;

            return [
              TextSpan(
                text: chunk.text,
                style: baseStyle.copyWith(
                  height: lineHeight,
                  decoration: shouldUnderline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: decorationColor,
                  decorationThickness: decorationThickness,
                  decorationStyle: TextDecorationStyle.solid,
                ),
                mouseCursor: SystemMouseCursors.click,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    if (chunk.support != null) {
                      widget.onSupportSelected?.call(chunk.support);
                    }
                  },
                onEnter: (_) => setState(() => _hoveredSupport = chunk.support),
                onExit: (_) => setState(() => _hoveredSupport = null),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Transform.translate(
                    offset: const Offset(0, 4),
                    child: const Icon(
                      Icons.diamond,
                      size: 8,
                      color: kGold,
                    ),
                  ),
                ),
              ),
            ];
          }
        }).toList(),
      ),
    );
  }

  List<GroundingCitation> _getReferencedCitations(GroundingSupport support) {
    final indices = support.groundingChunkIndices;
    return indices
        .where((idx) => idx >= 0 && idx < widget.groundingCitations.length)
        .map((idx) => widget.groundingCitations[idx])
        .toList();
  }
}
