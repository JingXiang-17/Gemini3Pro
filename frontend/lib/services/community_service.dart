import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/community_models.dart';

class CommunityService {
  // TODO: Replace with environment-specific URL for production
  // Development: http://localhost:8000/community
  // Production: https://your-backend-url.com/community
  static const String baseUrl = 'http://localhost:8000/community';

  Future<CommunityClaimData> getClaimData(String claimText) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/claim'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'claim_text': claimText}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CommunityClaimData.fromJson(data);
      } else {
        throw Exception('Failed to get claim data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting claim data: $e');
      rethrow;
    }
  }

  Future<PostClaimResponse> postClaim(String claimText, String aiVerdict) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/post'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'claim_text': claimText,
          'ai_verdict': aiVerdict,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PostClaimResponse.fromJson(data);
      } else {
        throw Exception('Failed to post claim: ${response.statusCode}');
      }
    } catch (e) {
      print('Error posting claim: $e');
      rethrow;
    }
  }

  Future<VoteResponse> submitVote({
    required String claimId,
    required String userId,
    required String userVerdict,
    String? notes,
    bool? vote,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vote'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'claim_id': claimId,
          'user_id': userId,
          'user_verdict': userVerdict,
          'notes': notes,
          'vote': vote,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return VoteResponse.fromJson(data);
      } else {
        throw Exception('Failed to submit vote: ${response.statusCode}');
      }
    } catch (e) {
      print('Error submitting vote: $e');
      rethrow;
    }
  }

  Future<List<ClaimSummary>> getTopClaims({int limit = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/top?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final claims = (data['claims'] as List)
            .map((claim) => ClaimSummary.fromJson(claim))
            .toList();
        return claims;
      } else {
        throw Exception('Failed to get top claims: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting top claims: $e');
      rethrow;
    }
  }

  Future<List<ClaimSummary>> searchClaims(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/search'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final claims = (data['claims'] as List)
            .map((claim) => ClaimSummary.fromJson(claim))
            .toList();
        return claims;
      } else {
        throw Exception('Failed to search claims: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching claims: $e');
      rethrow;
    }
  }

  Future<UserReputation> getUserReputation(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reputation/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserReputation.fromJson(data);
      } else {
        throw Exception('Failed to get user reputation: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting user reputation: $e');
      rethrow;
    }
  }
}
