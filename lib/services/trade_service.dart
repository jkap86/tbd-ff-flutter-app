import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/trade_model.dart';

class TradeService {
  // Propose a trade
  Future<Trade?> proposeTrade({
    required String token,
    required int leagueId,
    required int proposerRosterId,
    required int receiverRosterId,
    required List<int> playersGiving,
    required List<int> playersReceiving,
    String? message,
    bool notifyLeagueChat = true,
    bool showProposalDetails = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/trades/propose'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'league_id': leagueId,
          'proposer_roster_id': proposerRosterId,
          'receiver_roster_id': receiverRosterId,
          'players_giving': playersGiving,
          'players_receiving': playersReceiving,
          'message': message,
          'notify_league_chat': notifyLeagueChat,
          'show_proposal_details': showProposalDetails,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Trade.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Propose trade error: $e');
      return null;
    }
  }

  // Accept a trade
  Future<Trade?> acceptTrade({
    required String token,
    required int tradeId,
    required int rosterId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/trades/$tradeId/accept'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'roster_id': rosterId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Trade.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Accept trade error: $e');
      return null;
    }
  }

  // Reject a trade
  Future<Trade?> rejectTrade({
    required String token,
    required int tradeId,
    required int rosterId,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/trades/$tradeId/reject'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'roster_id': rosterId,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Trade.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Reject trade error: $e');
      return null;
    }
  }

  // Cancel a trade
  Future<Trade?> cancelTrade({
    required String token,
    required int tradeId,
    required int rosterId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/trades/$tradeId/cancel'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'roster_id': rosterId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Trade.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Cancel trade error: $e');
      return null;
    }
  }

  // Get a single trade
  Future<Trade?> getTrade(int tradeId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/trades/$tradeId'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Trade.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Get trade error: $e');
      return null;
    }
  }

  // Get all trades for a league
  Future<List<Trade>> getLeagueTrades(int leagueId, {String? status}) async {
    try {
      String url = '${ApiConfig.baseUrl}/api/leagues/$leagueId/trades';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tradesData = data['data'] as List;
        return tradesData.map((json) => Trade.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get league trades error: $e');
      return [];
    }
  }

  // Get all trades for a roster
  Future<List<Trade>> getRosterTrades(int rosterId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/rosters/$rosterId/trades'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tradesData = data['data'] as List;
        return tradesData.map((json) => Trade.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get roster trades error: $e');
      return [];
    }
  }
}
