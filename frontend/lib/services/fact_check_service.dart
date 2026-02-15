import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/grounding_models.dart';

class FactCheckService {
  final String baseUrl = kReleaseMode
      ? 'https://analyze-r4zi2m3nfa-uc.a.run.app'
      : 'http://127.0.0.1:8080';

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

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return AnalysisResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Failed to analyze: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }
}
