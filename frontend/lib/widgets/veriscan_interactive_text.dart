import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/grounding_models.dart';
import '../utils/grounding_parser.dart';
import 'citation_popup.dart';

class VeriscanInteractiveText extends StatefulWidget {
  final String analysisText;
  final List<GroundingSupport> groundingSupports;
  final List<GroundingCitation> groundingCitations;

  const VeriscanInteractiveText({
    super.key,
    required this.analysisText,
    required this.groundingSupports,
    required this.groundingCitations,
  });

  @override
  State<VeriscanInteractiveText> createState() =>
      _VeriscanInteractiveTextState();
}

class _VeriscanInteractiveTextState extends State<VeriscanInteractiveText> {
  // ===========================================================================
  //  UI TUNING VARIABLES - ADJUST THESE TO TWEAK HIGHLIGHT LOOK
  // ===========================================================================

  // 1. Line Spacing: Controls the vertical gap between lines of text.
  //    Higher value = More gap between ribbons.
  static const double kStrutHeight = 2.0;

  // 2. Highlight Height: Scale factor for the text height when active.
  //    Controls "Inner Thickness" / Height of the core box.
  //    - 1.0 = Normal Text Height
  //    - 0.85 = Tight/Shrunken
  //    - Increase to 0.95 or 1.0 to "cover whole text".
  static const double kActiveSpanHeight = 1.0;

  // 3. Highlight Padding/Rounding: Thickness of the stroke around the box.
  //    Adds "fatness" and controls corner radius.
  //    - Radius = StrokeWidth / 2.
  static const double kActiveStrokeWidth = 1.0;

  // ===========================================================================

  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  // Track currently active and hovered supports
  GroundingSupport? _activeSupport;
  GroundingSupport? _hoveredSupport;

  void _showPopup(GroundingSupport support) {
    setState(() {
      _activeSupport = support;
    });
    _overlayController.show();
  }

  void _hidePopup() {
    _overlayController.hide();
    setState(() {
      _activeSupport = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.analysisText.isEmpty) return const SizedBox();

    final chunks =
        GroundingParser.parse(widget.analysisText, widget.groundingSupports);
    final theme = Theme.of(context);

    // Standard Font setup
    const double kFontSize = 15.0;

    // Enforce layout spacing
    final strutStyle = StrutStyle(
      fontSize: kFontSize,
      height: kStrutHeight,
      forceStrutHeight: true,
      leading: 0.5,
    );

    // Base Style for plain text
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
          if (_activeSupport == null) return const SizedBox();

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
                  citations: _getReferencedCitations(_activeSupport!),
                  onClose: _hidePopup,
                ),
              ),
            ),
          );
        },
        child: RichText(
          key: ValueKey(
              '${widget.analysisText}_${_activeSupport?.hashCode ?? 0}_${_hoveredSupport?.hashCode ?? 0}'),
          strutStyle: strutStyle,
          text: TextSpan(
            style: baseStyle,
            children: chunks.expand((chunk) {
              if (chunk.type == ChunkType.plain) {
                return [TextSpan(text: chunk.text)];
              } else {
                final isSelected = _activeSupport == chunk.support;
                final isHovered = _hoveredSupport == chunk.support;

                final Paint? backgroundPaint = isSelected
                    ? (Paint()
                      ..color = kGold.withValues(alpha: 0.2)
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = kActiveStrokeWidth // TWEAKABLE
                      ..strokeJoin = StrokeJoin.round
                      ..strokeCap = StrokeCap.round)
                    : null;

                // Active/Hover height
                final double? spanHeight =
                    isSelected ? kActiveSpanHeight : 1.0; // TWEAKABLE

                // Hover: Thin Underline
                final TextDecoration decoration = (isHovered && !isSelected)
                    ? TextDecoration.underline
                    : TextDecoration.none;

                return [
                  TextSpan(
                    text: chunk.text,
                    style: baseStyle.copyWith(
                      height: spanHeight,
                      background: backgroundPaint,
                      decoration: decoration,
                      decorationColor: kGold.withValues(alpha: 0.6),
                      decorationThickness: 1.0,
                    ),
                    mouseCursor: SystemMouseCursors.click,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        if (chunk.support != null) {
                          _showPopup(chunk.support!);
                        }
                      },
                    onEnter: (_) =>
                        setState(() => _hoveredSupport = chunk.support),
                    onExit: (_) => setState(() => _hoveredSupport = null),
                  ),
                  // Superscript Gold Diamond
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

  List<GroundingCitation> _getReferencedCitations(GroundingSupport support) {
    final indices = support.groundingChunkIndices;
    return indices
        .where((idx) => idx >= 0 && idx < widget.groundingCitations.length)
        .map((idx) => widget.groundingCitations[idx])
        .toList();
  }
}
