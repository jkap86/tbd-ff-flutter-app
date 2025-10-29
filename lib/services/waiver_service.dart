import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/waiver_claim.dart';
import '../models/transaction.dart';

class WaiverService {
  /// Submit a waiver claim
  Future<WaiverClaim?> submitClaim({
    required String token,
    required int leagueId,
    required int rosterId,
    required int playerId,
    int? dropPlayerId,
    required int bidAmount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/leagues/$leagueId/waivers/claim'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'roster_id': rosterId,
          'player_id': playerId,
          'drop_player_id': dropPlayerId,
          'bid_amount': bidAmount,
        }),
      );

      debugPrint('[WaiverService] Submit claim response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return WaiverClaim.fromJson(data['data']);
      } else {
        debugPrint('[WaiverService] Submit claim error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[WaiverService] Submit claim exception: $e');
      return null;
    }
  }

  /// Get all waiver claims for a league
  Future<List<WaiverClaim>> getLeagueClaims({
    required String token,
    required int leagueId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/leagues/$leagueId/waivers/claims'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      debugPrint('[WaiverService] Get league claims response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final claimsData = data['data'] as List;
        return claimsData.map((json) => WaiverClaim.fromJson(json)).toList();
      } else {
        debugPrint('[WaiverService] Get league claims error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[WaiverService] Get league claims exception: $e');
      return [];
    }
  }

  /// Get waiver claims for a specific roster
  Future<List<WaiverClaim>> getRosterClaims({
    required String token,
    required int rosterId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/rosters/$rosterId/waivers/claims'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      debugPrint('[WaiverService] Get roster claims response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final claimsData = data['data'] as List;
        return claimsData.map((json) => WaiverClaim.fromJson(json)).toList();
      } else {
        debugPrint('[WaiverService] Get roster claims error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[WaiverService] Get roster claims exception: $e');
      return [];
    }
  }

  /// Cancel a waiver claim
  Future<bool> cancelClaim({
    required String token,
    required int claimId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/waivers/claims/$claimId'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      debugPrint('[WaiverService] Cancel claim response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('[WaiverService] Cancel claim error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[WaiverService] Cancel claim exception: $e');
      return false;
    }
  }

  /// Pick up a free agent
  Future<Transaction?> pickupFreeAgent({
    required String token,
    required int leagueId,
    required int rosterId,
    required int playerId,
    int? dropPlayerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/leagues/$leagueId/transactions/free-agent'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'roster_id': rosterId,
          'player_id': playerId,
          'drop_player_id': dropPlayerId,
        }),
      );

      debugPrint('[WaiverService] Pickup free agent response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Transaction.fromJson(data['data']);
      } else {
        debugPrint('[WaiverService] Pickup free agent error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[WaiverService] Pickup free agent exception: $e');
      return null;
    }
  }

  /// Get transaction history for a league
  Future<List<Transaction>> getTransactions({
    required String token,
    required int leagueId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/leagues/$leagueId/transactions'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      debugPrint('[WaiverService] Get transactions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactionsData = data['data'] as List;
        return transactionsData.map((json) => Transaction.fromJson(json)).toList();
      } else {
        debugPrint('[WaiverService] Get transactions error: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[WaiverService] Get transactions exception: $e');
      return [];
    }
  }
}
