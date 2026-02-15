import 'package:flutter/foundation.dart';
import '../models/grounding_models.dart';

enum ChunkType { plain, support }

class TextChunk {
  final String text;
  final ChunkType type;
  final GroundingSupport? support;

  TextChunk({
    required this.text,
    required this.type,
    this.support,
  });
}

class GroundingParser {
  /// Parses the [text] using [supports] to create a list of aggregated interactive [TextChunk]s.
  static List<TextChunk> parse(String text, List<GroundingSupport> supports) {
    if (text.isEmpty) return [];
    if (supports.isEmpty) {
      return [TextChunk(text: text, type: ChunkType.plain)];
    }

    // 1. Sort supports by start index
    final sortedSupports = List<GroundingSupport>.from(supports)
      ..sort((a, b) => a.segment.startIndex.compareTo(b.segment.startIndex));

    List<TextChunk> rawChunks = [];
    int currentIndex = 0;

    for (var support in sortedSupports) {
      final start = support.segment.startIndex;
      final end = support.segment.endIndex;

      if (start < currentIndex || start >= text.length) continue;

      final safeEnd = end > text.length ? text.length : end;

      // Add plain text before this segment
      if (start > currentIndex) {
        rawChunks.add(TextChunk(
          text: text.substring(currentIndex, start),
          type: ChunkType.plain,
        ));
      }

      // Add the support segment
      rawChunks.add(TextChunk(
        text: text.substring(start, safeEnd),
        type: ChunkType.support,
        support: support,
      ));

      currentIndex = safeEnd;
    }

    // Add remaining plain text
    if (currentIndex < text.length) {
      rawChunks.add(TextChunk(
        text: text.substring(currentIndex),
        type: ChunkType.plain,
      ));
    }

    // 2. Perform Greedy Aggregation (Sentential Aggregation)
    return _aggregateChunks(rawChunks);
  }

  static List<TextChunk> _aggregateChunks(List<TextChunk> chunks) {
    if (chunks.isEmpty) return [];

    final List<TextChunk> aggregated = [];
    int i = 0;

    while (i < chunks.length) {
      TextChunk current = chunks[i];

      // If it's plain text, check if next chunks are also plain or empty whitespace
      if (current.type == ChunkType.plain) {
        String mergedText = current.text;
        int j = i + 1;
        while (j < chunks.length && chunks[j].type == ChunkType.plain) {
          mergedText += chunks[j].text;
          j++;
        }
        aggregated.add(TextChunk(text: mergedText, type: ChunkType.plain));
        i = j;
        continue;
      }

      // If it's a support chunk, look ahead for matching ones
      if (current.type == ChunkType.support) {
        String mergedText = current.text;
        final currentIndices = current.support!.groundingChunkIndices;
        int j = i + 1;

        while (j < chunks.length) {
          final next = chunks[j];

          // Case 1: Next is identical support - MERGE
          if (next.type == ChunkType.support &&
              _isSameCitationSet(
                  currentIndices, next.support!.groundingChunkIndices)) {
            mergedText += next.text;
            j++;
            continue;
          }

          // Case 2: Next is trivial whitespace/punctuation between identical supports - MERGE
          // Only peek further if the chunk after this punctuation is an identical support
          if (next.type == ChunkType.plain && next.text.trim().isEmpty) {
            if (j + 1 < chunks.length) {
              final afterNext = chunks[j + 1];
              if (afterNext.type == ChunkType.support &&
                  _isSameCitationSet(currentIndices,
                      afterNext.support!.groundingChunkIndices)) {
                mergedText += next.text; // consume whitespace
                mergedText += afterNext.text; // consume matching support
                j += 2;
                continue;
              }
            }
          }

          break; // Stop merging
        }

        aggregated.add(TextChunk(
          text: mergedText,
          type: ChunkType.support,
          support: current.support, // Use first support as metadata holder
        ));
        i = j;
      }
    }

    return aggregated;
  }

  static bool _isSameCitationSet(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final sortedA = List<int>.from(a)..sort();
    final sortedB = List<int>.from(b)..sort();
    return listEquals(sortedA, sortedB);
  }
}
