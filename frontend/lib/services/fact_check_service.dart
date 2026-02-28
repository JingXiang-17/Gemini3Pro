import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/grounding_models.dart';

class FactCheckService {
  // Allow temporary override via --dart-define=BACKEND_URL
  static const _envOverride =
      String.fromEnvironment('BACKEND_URL', defaultValue: '');
  final String baseUrl = _envOverride.isNotEmpty
      ? (_envOverride.endsWith('/analyze')
          ? _envOverride.replaceAll(RegExp(r'\/analyze\/?'), '')
          : _envOverride)
      : (kReleaseMode
          ? 'https://analyze-r4zi2m3nfa-uc.a.run.app'
          : 'http://127.0.0.1:8000');

  Future<AnalysisResponse> analyzeNews({
    String? text,
    List<SourceAttachment>? attachments,
  }) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));

      // Prepare metadata
      final List<String> urls = attachments
              ?.where((a) => a.type == AttachmentType.link && a.url != null)
              .map((a) => a.url!)
              .toList() ??
          [];

      final metadata = {
        "request_id": DateTime.now().millisecondsSinceEpoch.toString(),
        "text_claim": text ?? "",
        "urls": urls,
      };

      request.fields['metadata'] = jsonEncode(metadata);

      // 1. Client-Side Size Validation (50MB Total Limit)
      int totalSizeBytes = 0;
      if (attachments != null) {
        for (final attachment in attachments) {
          if (attachment.type != AttachmentType.link &&
              attachment.file != null) {
            final file = attachment.file as PlatformFile;
            totalSizeBytes += file.size;
          }
        }
      }

      if (totalSizeBytes > 50 * 1024 * 1024) {
        throw Exception(
            'File Size Limit Exceeded. Please ensure total upload is under 50MB (Current: ${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB).');
      }

      // Add files
      if (attachments != null) {
        for (final attachment in attachments) {
          if (attachment.type != AttachmentType.link &&
              attachment.file != null) {
            final file = attachment.file as PlatformFile;
            if (file.bytes != null) {
              final mimeType = file.name.toLowerCase().endsWith('pdf')
                  ? 'application/pdf'
                  : 'image/jpeg';

              request.files.add(http.MultipartFile.fromBytes(
                'files',
                file.bytes!,
                filename: file.name,
                contentType: MediaType.parse(mimeType),
              ));
            }
          }
        }
      }

      debugPrint(
          'SERVICE DEBUG: Sending multimodal request with ${request.files.length} files and ${urls.length} URLs');

      // Send with extended timeout for cold starts
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException(
              'Backend is warming up. Retrying automatically...');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return AnalysisResponse.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 413) {
        throw Exception(
            'File Size Limit Exceeded. Please ensure individual files are under 20MB and total upload is under 50MB.');
      } else {
        throw Exception(
            'Failed to analyze: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }
}
