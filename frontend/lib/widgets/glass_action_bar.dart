import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/grounding_models.dart';
import '../widgets/juicy_button.dart';

class GlassActionBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onAnalyze;
  final List<SourceAttachment> attachments;
  final Map<String, GlobalKey> chipKeys;
  final Function(SourceAttachment) onAddAttachment;
  final Function(String) onRemoveAttachment;
  final bool isLoading;

  const GlassActionBar({
    super.key,
    required this.controller,
    required this.onAnalyze,
    required this.attachments,
    required this.chipKeys,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.isLoading,
  });

  @override
  State<GlassActionBar> createState() => _GlassActionBarState();
}

class _GlassActionBarState extends State<GlassActionBar> {
  bool _isUpdating = false;
  bool _showSocialReminder = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_urlDetector);
  }

  void _urlDetector() {
    if (_isUpdating) return;

    final text = widget.controller.text;
    // Robust URL Regex covering http, https, www, and common TLDs
    final urlRegex = RegExp(
        r'((?:https?:\/\/|www\.)[^\s]+|[a-zA-Z0-9.-]+\.(?:com|org|net|gov|edu|io|co|me|site|info)[^\s]*)',
        caseSensitive: false);

    final matches = urlRegex.allMatches(text);

    // Social Detection
    final socialRegex = RegExp(
        r'(instagram\.com|facebook\.com|twitter\.com|x\.com|tiktok\.com)',
        caseSensitive: false);
    final hasSocial = socialRegex.hasMatch(text);
    if (_showSocialReminder != hasSocial) {
      setState(() => _showSocialReminder = hasSocial);
    }

    if (matches.isEmpty) return;

    String currentText = text;
    bool changed = false;

    // Process from end to start to avoid index shifting during replacement
    for (final match in matches.toList().reversed) {
      final url = match.group(0)!;
      final matchEnd = match.end;

      // TRIGGER CONDITIONS:
      // 1. URL is followed by whitespace (User finished typing)
      // 2. URL is at the end of text and starts with http/www (User pasted)
      final bool hasSpaceAfter =
          matchEnd < text.length && RegExp(r'\s').hasMatch(text[matchEnd]);
      final bool isExplicitFullLinkAtEnd = matchEnd == text.length &&
          (url.contains('://') || url.startsWith('www.'));

      if (hasSpaceAfter || isExplicitFullLinkAtEnd) {
        if (!widget.attachments.any((a) => a.url == url)) {
          _isUpdating = true;

          String title = _formatUrlTitle(url);

          widget.onAddAttachment(SourceAttachment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            type: AttachmentType.link,
            url: url,
          ));

          // Remove the Link + the space if there was one
          int endPos = hasSpaceAfter ? matchEnd + 1 : matchEnd;
          currentText = currentText.replaceRange(match.start, endPos, '');
          changed = true;
          _isUpdating = false;
        }
      }
    }

    if (changed) {
      _isUpdating = true;
      // Use PostFrameCallback for "Atomic" clear/update to avoid cursor jumps
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Clear or set text to remaining content
        final trimmedText = currentText.trimLeft();
        widget.controller.value = TextEditingValue(
          text: trimmedText,
          selection: TextSelection.collapsed(offset: trimmedText.length),
        );
        _isUpdating = false;
      });
    }
  }

  String _formatUrlTitle(String url) {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'http://$url');
      String host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      if (host.isEmpty) return url;
      return host[0].toUpperCase() + host.substring(1).split('.').first;
    } catch (_) {
      return url.split('/').last.isEmpty ? url : url.split('/').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const ValueKey('glass_action_bar_container'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black, // Pure black
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.5),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.attachments.isNotEmpty) ...[
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: widget.attachments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final attachment = widget.attachments[index];
                      final chipKey =
                          widget.chipKeys[attachment.id] ?? GlobalKey();
                      if (!widget.chipKeys.containsKey(attachment.id)) {
                        widget.chipKeys[attachment.id] = chipKey;
                      }
                      return _AttachmentChip(
                        key: chipKey,
                        attachment: attachment,
                        onRemove: () =>
                            widget.onRemoveAttachment(attachment.id),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.white10,
                  ),
                ),
              ],
              if (_showSocialReminder)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8.0, left: 48, right: 48),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tips_and_updates,
                            color: Color(0xFFD4AF37), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Pro-Tip: Social media links can be volatile. For best results, upload a screenshot or screen recording as forensic evidence.",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFD4AF37),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  _PickerButton(
                      key: const ValueKey('add_button'),
                      onAdd: widget.onAddAttachment),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: TextField(
                        controller: widget.controller,
                        maxLines: null,
                        minLines: 1,
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: "Enter claim or attach files",
                          hintStyle:
                              TextStyle(color: Colors.white38, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  JuicyButton(
                    key: const ValueKey('analyze_button'),
                    // We use an empty function () {} if it's loading so it doesn't double-submit
                    onTap: widget.isLoading ? () {} : widget.onAnalyze, 
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: widget.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.biotech, // Scan icon
                                color: Colors.black,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final Function(SourceAttachment) onAdd;
  const _PickerButton({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -150),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
        ),
        child: const Icon(Icons.add, color: Color(0xFFD4AF37), size: 20),
      ),
      onSelected: (value) async {
        if (value == 'image') {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (result != null) {
            onAdd(SourceAttachment(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: result.files.first.name,
              type: AttachmentType.image,
              file: result.files.first,
            ));
          }
        } else if (value == 'pdf') {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            withData: true,
          );
          if (result != null) {
            onAdd(SourceAttachment(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: result.files.first.name,
              type: AttachmentType.pdf,
              file: result.files.first,
            ));
          }
        } else if (value == 'link') {
          // In a real app, show a dialog. For now, rely on auto-detector.
        }
      },
      itemBuilder: (context) => [
        _buildMenuItem('Capture Image', Icons.camera_alt, 'image'),
        _buildMenuItem('Upload PDF', Icons.picture_as_pdf, 'pdf'),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      String text, IconData icon, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          const SizedBox(width: 12),
          Text(text,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final SourceAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentChip(
      {super.key, required this.attachment, required this.onRemove});

  String _truncateFileName(String name) {
    if (name.length <= 12) return name;

    // Tail-Preservation Logic: Extract first 4 and last 4 chars
    final String extension = name.substring(name.length - 4);
    final String prefix = name.substring(0, 4);
    return "$prefix...$extension";
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (attachment.type) {
      case AttachmentType.image:
        icon = Icons.image;
        break;
      case AttachmentType.pdf:
        icon = Icons.description;
        break;
      case AttachmentType.link:
        icon = Icons.link;
        break;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4), // Added leading spacer for icon
          Icon(icon, color: const Color(0xFFD4AF37), size: 16),
          const SizedBox(width: 4), // Reduced spacer
          Flexible(
            child: Text(
              _truncateFileName(attachment.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(Icons.close, color: Colors.white38, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
