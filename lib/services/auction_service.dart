import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auction_model.dart';
import '../models/player_model.dart';

class AuctionService {
  // Get active nominations for a draft
  Future<List<AuctionNomination>> getActiveNominations({
    required String token,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/drafts/$draftId/auction/nominations');
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => AuctionNomination.fromJson(json)).toList();
      } else {
        debugPrint('Failed to get nominations: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting nominations: $e');
      return [];
    }
  }

  // Get bid history for a nomination
  Future<List<AuctionBid>> getBidHistory({
    required String token,
    required int nominationId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/auction/nominations/$nominationId/bids');
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => AuctionBid.fromJson(json)).toList();
      } else {
        debugPrint('Failed to get bid history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting bid history: $e');
      return [];
    }
  }

  // Nominate a player
  Future<Map<String, dynamic>?> nominatePlayer({
    required String token,
    required int draftId,
    required int playerId,
    required int rosterId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/drafts/$draftId/auction/nominate');
      final response = await http.post(
        url,
        headers: ApiConfig.getAuthHeaders(token),
        body: json.encode({
          'player_id': playerId,
          'roster_id': rosterId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        debugPrint('Failed to nominate player: ${error['error']}');
        throw Exception(error['error'] ?? 'Failed to nominate player');
      }
    } catch (e) {
      debugPrint('Error nominating player: $e');
      rethrow;
    }
  }

  // Place a bid on a nomination
  Future<Map<String, dynamic>?> placeBid({
    required String token,
    required int nominationId,
    required int rosterId,
    required int maxBid,
    required int draftId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/auction/nominations/$nominationId/bid');
      final response = await http.post(
        url,
        headers: ApiConfig.getAuthHeaders(token),
        body: json.encode({
          'roster_id': rosterId,
          'max_bid': maxBid,
          'draft_id': draftId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        debugPrint('Failed to place bid: ${error['error']}');
        throw Exception(error['error'] ?? 'Failed to place bid');
      }
    } catch (e) {
      debugPrint('Error placing bid: $e');
      rethrow;
    }
  }

  // Get available players for auction (not yet nominated or won)
  Future<List<Player>> getAvailablePlayersForAuction({
    required String token,
    required int draftId,
    String? position,
    String? team,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (position != null) queryParams['position'] = position;
      if (team != null) queryParams['team'] = team;
      if (search != null) queryParams['search'] = search;

      final url = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/drafts/$draftId/auction/available-players')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Player.fromJson(json)).toList();
      } else {
        debugPrint('Failed to get available players: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting available players: $e');
      return [];
    }
  }

  // Get roster budget info
  Future<Map<String, dynamic>?> getRosterBudget({
    required String token,
    required int draftId,
    required int rosterId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/drafts/$draftId/auction/rosters/$rosterId/budget');
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to get roster budget: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting roster budget: $e');
      return null;
    }
  }

  // Get auction activity feed
  Future<List<ActivityItem>> getActivityFeed({
    required String token,
    required int draftId,
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/drafts/$draftId/auction/activity?limit=$limit');
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ActivityItem.fromJson(json)).toList();
      } else {
        debugPrint('Failed to get activity feed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting activity feed: $e');
      return [];
    }
  }
}
