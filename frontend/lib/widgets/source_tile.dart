import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../models/grounding_models.dart';

class SourceTile extends StatelessWidget {
  final String title;
  final String url;
  final List<SourceAttachment>? attachments;
  final String status;
  final int count;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SourceTile({
    super.key,
    required this.title,
    required this.url,
    this.attachments,
    this.status = 'live',
    this.count = 1,
    this.isActive = false,
    this.onTap,
    this.onDelete,
  });

  bool get _isUploadedFile => !url.startsWith('http');

  String get _actionLabel {
    if (_isUploadedFile) {
      final attachment = _findAttachment();
      if (attachment != null && attachment.file != null) {
        return "VIEW EVIDENCE";
      }
      return "VIEW ATTACHMENT";
    }
    return status == 'live' ? "OPEN LINK" : "VIEW DIAGNOSTIC";
  }

  SourceAttachment? _findAttachment() {
    return attachments?.firstWhere(
      (a) => a.title == title || a.url == url,
      orElse: () => SourceAttachment(
        id: 'external',
        title: title,
        type: AttachmentType.link,
      ),
    );
  }

  Future<void> _handleViewAction(BuildContext context) async {
    if (_isUploadedFile) {
      final attachment = _findAttachment();
      if (attachment != null && attachment.file != null) {
        _openNativeFile(context, attachment.file as PlatformFile);
      } else {
        _showForensicNote(context);
      }
    } else if (status == 'dead' || status == 'restricted') {
      _showDiagnosticPopup(context);
    } else {
      _launchUrl();
    }
  }

  void _showDiagnosticPopup(BuildContext context) {
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
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
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

  void _openNativeFile(BuildContext context, PlatformFile file) {
    if (file.bytes == null) {
      _showForensicNote(context);
      return;
    }

    final String mimeType = _getMimeType(file.name);

    if (mimeType.startsWith('image/')) {
      _showImageDialog(context, file);
    } else if (mimeType == 'application/pdf') {
      _showPdfDialog(context, file);
    } else {
      final blob = html.Blob([file.bytes!], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
    }
  }

  void _showPdfDialog(BuildContext context, PlatformFile file) {
    final blob = html.Blob([file.bytes!], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Register the factory for this specific PDF URL
    final viewId = 'pdf-tile-view-${file.name.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      return html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        insetPadding: const EdgeInsets.all(40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    file.name,
                    style: GoogleFonts.outfit(
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: HtmlElementView(viewType: viewId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, PlatformFile file) {
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

  void _showForensicNote(BuildContext context) {
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
          "This is an analyzed attachment. To view the original, please refer to your local file: $title",
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
    final bool isInaccessible = status == 'dead' || status == 'restricted';

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? const Color(0xFFD4AF37) : Colors.white10,
                width: isActive ? 1.0 : 0.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap ?? () => _handleViewAction(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Favicon Placeholder
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isInaccessible
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                            isInaccessible
                                ? Icons.warning_amber_rounded
                                : Icons.link,
                            color: isInaccessible
                                ? Colors.white24
                                : const Color(0xFFD4AF37),
                            size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            color: isInaccessible
                                ? Colors.white24
                                : Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            decoration: isInaccessible
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFD4AF37), size: 16),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      else
                        IconButton(
                          tooltip: _actionLabel,
                          icon: Icon(
                              _isUploadedFile
                                  ? Icons.visibility_outlined
                                  : (isInaccessible
                                      ? Icons.report_problem_outlined
                                      : Icons.open_in_new),
                              color: (_isUploadedFile || !isInaccessible)
                                  ? const Color(0xFFD4AF37)
                                  : Colors.white24,
                              size: 14),
                          onPressed: () => _handleViewAction(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (count > 1)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  "×$count",
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
