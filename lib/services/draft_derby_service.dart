import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/draft_derby_model.dart';

class DraftDerbyService {
  /// Create a new derby for a draft
  Future<DraftDerby?> createDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/drafts/$draftId/derby/create');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Create derby response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return DraftDerby.fromJson(data['data']);
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Create derby error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Create derby exception: $e');
      return null;
    }
  }

  /// Start the derby
  Future<DraftDerby?> startDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/drafts/$draftId/derby/start');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Start derby response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DraftDerby.fromJson(data['data']);
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Start derby error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Start derby exception: $e');
      return null;
    }
  }

  /// Get derby details
  Future<DraftDerbyWithDetails?> getDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/drafts/$draftId/derby');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Get derby response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DraftDerbyWithDetails.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        debugPrint('[DerbyService] Derby not found');
        return null;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Get derby error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Get derby exception: $e');
      return null;
    }
  }

  /// Make a derby selection
  Future<Map<String, dynamic>?> makeSelection({
    required String token,
    required int draftId,
    required int rosterId,
    required int draftPosition,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/drafts/$draftId/derby/select');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'roster_id': rosterId,
          'draft_position': draftPosition,
        }),
      );

      debugPrint('[DerbyService] Make selection response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'selection': DraftDerbySelection.fromJson(data['data']['selection']),
          'derby': DraftDerbyWithDetails.fromJson(data['data']['derby']),
        };
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Make selection error: ${errorData['message']}');
        throw Exception(errorData['message'] ?? 'Failed to make selection');
      }
    } catch (e) {
      debugPrint('[DerbyService] Make selection exception: $e');
      rethrow;
    }
  }

  /// Skip current turn (for timeout or commissioner action)
  Future<DraftDerbyWithDetails?> skipTurn({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/drafts/$draftId/derby/skip');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('[DerbyService] Skip turn response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DraftDerbyWithDetails.fromJson(data['data']['derby'] ?? data['data']);
      } else {
        final errorData = json.decode(response.body);
        debugPrint('[DerbyService] Skip turn error: ${errorData['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[DerbyService] Skip turn exception: $e');
      return null;
    }
  }
}
