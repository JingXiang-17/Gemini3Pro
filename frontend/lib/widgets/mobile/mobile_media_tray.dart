import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/grounding_models.dart';

class MobileMediaTray extends StatelessWidget {
  final List<SourceAttachment> attachments;
  final Function(String) onRemoveAttachment;

  const MobileMediaTray({
    super.key,
    required this.attachments,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _buildAttachmentItem(attachment);
        },
      ),
    );
  }

  Widget _buildAttachmentItem(SourceAttachment attachment) {
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
      width: attachment.type == AttachmentType.image ? 48 : 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          Center(
            child: attachment.type == AttachmentType.image
                ? const Icon(Icons.image, color: Color(0xFFD4AF37), size: 24)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: const Color(0xFFD4AF37), size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            attachment.title,
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () => onRemoveAttachment(attachment.id),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel,
                    color: Color(0xFFD4AF37), size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
