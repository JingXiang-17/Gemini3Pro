import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/file_viewer_helper.dart'; // <--- Using our safe helper
import '../models/grounding_models.dart';

class EvidenceCard extends StatefulWidget {
  final String title;
  final String snippet;
  final String url;
  final String? sourceFile;
  final List<SourceAttachment>? attachments;
  final String status;
  final bool isActive;
  final VoidCallback? onDelete;

  const EvidenceCard({
    super.key,
    required this.title,
    required this.snippet,
    required this.url,
    this.sourceFile,
    this.attachments,
    this.status = 'live',
    this.isActive = false,
    this.onDelete,
  });

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard> {
  bool _isExpanded = false;

  bool get _isUploadedFile =>
      widget.sourceFile != null || !widget.url.startsWith('http');

  String get _actionLabel {
    if (_isUploadedFile) {
      final attachment = _findAttachment();
      if (attachment != null && attachment.file != null) {
        return "VIEW EVIDENCE";
      }
      return "VIEW ATTACHMENT";
    }
    return "VISIT SOURCE";
  }

  SourceAttachment? _findAttachment() {
    return widget.attachments?.firstWhere(
      (a) => a.title == widget.sourceFile || a.title == widget.title,
      orElse: () => SourceAttachment(
        id: 'external',
        title: widget.sourceFile ?? widget.title,
        type: AttachmentType.link,
      ),
    );
  }

  Future<void> _handleViewAction() async {
    if (_isUploadedFile) {
      final attachment = _findAttachment();
      if (attachment != null && attachment.file != null) {
        _openNativeFile(attachment.file as PlatformFile);
      } else {
        _showForensicNote();
      }
    } else if (widget.status == 'dead' || widget.status == 'restricted') {
      _showDiagnosticPopup();
    } else {
      _launchUrl();
    }
  }

  void _showDiagnosticPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            Text(
              "Forensic Diagnostic",
              style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Notice: This external link is inaccessible or restricted. Forensic analysis was based on the multimodal ingestion provided during the upload.",
          style: GoogleFonts.outfit(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("DISMISS",
                style: GoogleFonts.outfit(
                    color: const Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl() async {
    if (widget.url.isEmpty) return;
    final Uri uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  // UPDATED: Now uses our cross-platform helper instead of direct web code
  void _openNativeFile(PlatformFile file) {
    if (file.bytes == null) {
      _showForensicNote();
      return;
    }

    final String mimeType = _getMimeType(file.name);

    if (mimeType.startsWith('image/')) {
      _showImageDialog(file);
    } else {
      // Delegate PDFs and other files to our smart helper
      openPlatformFile(context, file);
    }
  }

  void _showImageDialog(PlatformFile file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  file.bytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              file.name,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showForensicNote() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Forensic Note",
          style: GoogleFonts.outfit(
              color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This is an analyzed attachment. To view the original, please refer to your local file: ${widget.sourceFile ?? widget.title}",
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK",
                style: GoogleFonts.outfit(color: const Color(0xFFD4AF37))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isActive
              ? const Color(0xFFD4AF37)
              : const Color(0xFFD4AF37).withOpacity(0.2),
          width: widget.isActive ? 1.0 : 0.5,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37)
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Color(0xFFD4AF37), size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Color(0xFFD4AF37), size: 18),
                              onPressed: widget.onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _actionLabel,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white24,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: "View Attachment or Link",
                                  icon: Icon(
                                      _isUploadedFile
                                          ? Icons.visibility_outlined
                                          : Icons.open_in_new,
                                      color: Colors.white54,
                                      size: 14),
                                  onPressed: _handleViewAction,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final textPainter = TextPainter(
                              text: TextSpan(
                                text: widget.snippet,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              maxLines: 3,
                              textDirection: TextDirection.ltr,
                            )..layout(maxWidth: constraints.maxWidth);

                            final bool isTruncated =
                                textPainter.didExceedMaxLines;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.snippet,
                                  maxLines: _isExpanded ? null : 3,
                                  overflow: _isExpanded
                                      ? null
                                      : TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                    height: 1.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                if (isTruncated) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _isExpanded
                                            ? "SHOW LESS"
                                            : "READ FULL TEXT",
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFD4AF37),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      AnimatedRotation(
                                        turns: _isExpanded ? 0.5 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: const Icon(
                                          Icons.expand_more,
                                          color: Color(0xFFD4AF37),
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}