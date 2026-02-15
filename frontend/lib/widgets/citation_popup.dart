import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/grounding_models.dart';

class CitationPopup extends StatelessWidget {
  final List<GroundingCitation> citations;
  final VoidCallback onClose;

  const CitationPopup({
    super.key,
    required this.citations,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) return const SizedBox();

    return Material(
      color: Colors.transparent,
      elevation: 8,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Sources",
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: onClose,
                    child: Icon(Icons.close,
                        size: 16, color: Theme.of(context).disabledColor),
                  ),
                ],
              ),
            ),

            // List of Sources
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                shrinkWrap: true,
                itemCount: citations.length,
                separatorBuilder: (ctx, i) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final citation = citations[index];
                  return _buildSourceItem(context, citation);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceItem(BuildContext context, GroundingCitation citation) {
    // Extract domain for favicon
    final uri = Uri.tryParse(citation.url);
    final domain = uri?.host ?? "unknown";
    final faviconUrl =
        "https://www.google.com/s2/favicons?domain=$domain&sz=64";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (citation.url.isNotEmpty)
              CachedNetworkImage(
                imageUrl: faviconUrl,
                width: 16,
                height: 16,
                placeholder: (context, url) =>
                    const Icon(Icons.public, size: 16),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.public, size: 16),
              ),
            if (citation.url.isNotEmpty) const SizedBox(width: 8),
            Expanded(
              child: Text(
                citation.title.isNotEmpty ? citation.title : "Reference",
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (citation.snippet.isNotEmpty)
          Text(
            citation.snippet,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        if (citation.url.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 24,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  final url = Uri.parse(citation.url);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: const Text("Open Link", style: TextStyle(fontSize: 10)),
              ),
            ),
          ),
      ],
    );
  }
}
