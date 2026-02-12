import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/grounding_models.dart';
import '../utils/grounding_parser.dart';
import 'citation_popup.dart';

class VeriscanInteractiveText extends StatefulWidget {
  final String analysisText;
  final List<GroundingSupport> groundingSupports;
  final List<GroundingCitation> groundingCitations;
  // CHANGED: activeSupport instead of activeCitationIndex
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
  // ===========================================================================
  //  UI TUNING VARIABLES
  // ===========================================================================
  static const double kStrutHeight = 2.0;
  // ===========================================================================

  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  // Internal state for popup management (still needed?)
  // Actually, if we use external activeSupport, we might not need internal _activeSupport
  // EXCEPT for hovering or transient states?
  // Let's rely on widget.activeSupport for HIGHLIGHTING.
  // But for POPUP, we might need internal state if the user clicks a diamond?
  // User interaction: "When a text segment is clicked... pass... to sidebar".
  // This implies external control.
  // But popup logic might persist.

  // Let's check existing popup logic. It uses _activeSupport.
  // If we change highlight logic to use widget.activeSupport, we should probably
  // sync them? Or keep popup separate?
  // User didn't ask to change popup behavior, just highlighting.
  // However, "Idle segments must return to...".
  // If we click away, activeSupport becomes null.

  GroundingSupport? _internalActiveSupport; // For popup only if needed?
  // Or just use widget.activeSupport?
  // If widget.activeSupport moves, the popup should probably follow or close.

  GroundingSupport? _hoveredSupport;

  @override
  Widget build(BuildContext context) {
    if (widget.analysisText.isEmpty) return const SizedBox();

    final chunks =
        GroundingParser.parse(widget.analysisText, widget.groundingSupports);
    final theme = Theme.of(context);

    const double kFontSize = 15.0;

    final strutStyle = StrutStyle(
      fontSize: kFontSize,
      height: kStrutHeight,
      forceStrutHeight: true,
      leading: 0.5,
    );

    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: kFontSize,
          height: 1.0,
        ) ??
        const TextStyle(fontSize: kFontSize, height: 1.0);

    const kGold = Color(0xFFD4AF37);

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          // Popup uses widget.activeSupport if available?
          // Or internal?
          // Let's use internal for now to avoid breaking popup on rapid clicks?
          // Or if external changes, we should update popup.
          final supportToShow = widget.activeSupport ?? _internalActiveSupport;

          if (supportToShow == null) return const SizedBox();

          return Positioned(
            width: 300,
            child: CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 10),
              child: TapRegion(
                onTapOutside: (_) => _hidePopup(),
                child: CitationPopup(
                  citations: _getReferencedCitations(supportToShow),
                  onClose: _hidePopup,
                ),
              ),
            ),
          );
        },
        child: RichText(
          key: ValueKey(
              '${widget.analysisText}_${widget.activeSupport?.hashCode ?? 0}_${_hoveredSupport?.hashCode ?? 0}'),
          strutStyle: strutStyle,
          text: TextSpan(
            style: baseStyle,
            children: chunks.expand((chunk) {
              if (chunk.type == ChunkType.plain) {
                return [TextSpan(text: chunk.text)];
              } else {
                // CHANGED: Highlight Logic
                // Only highlight if exact support object matches (referenced by pointer or ID)
                // Since GroundingSupport might not be const, we rely on reference equality or props?
                // They are likely same instances from the list.
                // Or compare startIndex/endIndex to be safe.

                final bool isSelected = widget.activeSupport != null &&
                    chunk.support != null &&
                    chunk.support!.segment.startIndex ==
                        widget.activeSupport!.segment.startIndex;

                final isHovered = _hoveredSupport == chunk.support;

                // TRIPLE-STATE UNDERLINE LOGIC
                // 1. Idle: No decoration (handled by default)
                // 2. Hover: Thin Gold Underline (1.0px, 0.4 opacity)
                // 3. Active: Thick Gold Underline (3.0px, 1.0 opacity)

                final bool shouldUnderline = isSelected || isHovered;

                final Color decorationColor = isSelected
                    ? kGold
                    : (isHovered
                        ? kGold.withValues(alpha: 0.4)
                        : Colors.transparent);

                final double decorationThickness = isSelected ? 3.0 : 1.0;

                // Adjust height to allow space for "Deep Offset" physics look
                // We use 1.8 for active to give breathing room
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
                          _showPopup(chunk.support!);
                          widget.onSupportSelected?.call(chunk.support);
                        }
                      },
                    onEnter: (_) =>
                        setState(() => _hoveredSupport = chunk.support),
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
        ),
      ),
    );
  }

  void _showPopup(GroundingSupport support) {
    setState(() {
      _internalActiveSupport = support;
    });
    _overlayController.show();
  }

  void _hidePopup() {
    _overlayController.hide();
    setState(() {
      _internalActiveSupport = null;
    });
    // Should we also clear external selection?
    // User says "Click-Away Logic" clears it.
    // If popup closes, does text stay highlighted?
    // User: "Idle segments must return to...".
    // Usually clicking 'X' on popup or outside clears it.
    // We already have TapRegion active.
    // If we want to clear external state:
    widget.onSupportSelected?.call(null);
  }

  List<GroundingCitation> _getReferencedCitations(GroundingSupport support) {
    // Helper to get citations for a support
    final indices = support.groundingChunkIndices;
    // Map indices to citation objects
    // Safety check bounds
    return indices
        .where((idx) => idx >= 0 && idx < widget.groundingCitations.length)
        .map((idx) => widget.groundingCitations[idx])
        .toList();
  }
}
