import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/draft_model.dart';
import '../models/draft_pick_model.dart';
import '../models/draft_order_model.dart';
import '../models/draft_chat_message_model.dart';
import '../models/player_model.dart';

class DraftService {
  // Create a new draft
  Future<Draft?> createDraft({
    required String token,
    required int leagueId,
    required String draftType,
    bool thirdRoundReversal = false,
    int pickTimeSeconds = 90,
    int rounds = 15,
    String timerMode = 'traditional',
    int? teamTimeBudgetSeconds,
    Map<String, dynamic>? settings,
    // Auction-specific
    int? startingBudget,
    int? minBid,
    int? nominationsPerManager,
    int? nominationTimerHours,
    bool? reserveBudgetPerSlot,
    // Derby-specific
    bool? derbyEnabled,
    int? derbyTimeLimitSeconds,
    String? derbyTimeoutBehavior,
  }) async {
    try {
      // Validate chess timer mode
      if (timerMode == 'chess' && teamTimeBudgetSeconds == null) {
        debugPrint('Chess timer mode requires teamTimeBudgetSeconds');
        return null;
      }

      final body = {
        'league_id': leagueId,
        'draft_type': draftType,
        'third_round_reversal': thirdRoundReversal,
        'pick_time_seconds': pickTimeSeconds,
        'rounds': rounds,
        'timer_mode': timerMode,
        'settings': settings ?? {},
      };

      // Add chess timer budget if provided
      if (teamTimeBudgetSeconds != null) {
        body['team_time_budget_seconds'] = teamTimeBudgetSeconds;
      }

      // Add auction-specific parameters if provided
      if (startingBudget != null) {
        body['starting_budget'] = startingBudget;
      }
      if (minBid != null) {
        body['min_bid'] = minBid;
      }
      if (nominationsPerManager != null) {
        body['nominations_per_manager'] = nominationsPerManager;
      }
      if (nominationTimerHours != null) {
        body['nomination_timer_hours'] = nominationTimerHours;
      }
      if (reserveBudgetPerSlot != null) {
        body['reserve_budget_per_slot'] = reserveBudgetPerSlot;
      }

      // Add derby-specific parameters if provided
      if (derbyEnabled != null) {
        body['derby_enabled'] = derbyEnabled;
      }
      if (derbyTimeLimitSeconds != null) {
        body['derby_time_limit_seconds'] = derbyTimeLimitSeconds;
      }
      if (derbyTimeoutBehavior != null) {
        body['derby_timeout_behavior'] = derbyTimeoutBehavior;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/create'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Create draft error: $e');
      return null;
    }
  }

  // Get draft by ID
  Future<Draft?> getDraft({required String token, required int draftId}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Get draft error: $e');
      return null;
    }
  }

  // Get draft by league ID
  Future<Draft?> getDraftByLeague({
    required String token,
    required int leagueId,
  }) async {
    try {
      final url = '${ApiConfig.baseUrl}/api/v1/leagues/$leagueId/draft';
      final headers = ApiConfig.getAuthHeaders(token);

      debugPrint('[DraftService] getDraftByLeague: url=$url');
      debugPrint('[DraftService] getDraftByLeague: headers=${headers.keys.toList()}');
      debugPrint('[DraftService] getDraftByLeague: hasAuthHeader=${headers.containsKey("Authorization")}');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('[DraftService] getDraftByLeague response: statusCode=${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      } else {
        debugPrint('[DraftService] getDraftByLeague error response: ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('Get draft by league error: $e');
      return null;
    }
  }

  // Set draft order (manual or randomized)
  Future<List<DraftOrder>> setDraftOrder({
    required String token,
    required int draftId,
    bool randomize = false,
    List<Map<String, int>>? order,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/order'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'randomize': randomize,
          if (order != null) 'order': order,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ordersData = data['data'] as List;
        return ordersData.map((json) => DraftOrder.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Set draft order error: $e');
      return [];
    }
  }

  // Get draft order
  Future<List<DraftOrder>> getDraftOrder({required String token, required int draftId}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/order'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ordersData = data['data'] as List;
        return ordersData.map((json) => DraftOrder.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get draft order error: $e');
      return [];
    }
  }

  // Start draft
  Future<Draft?> startDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/start'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Start draft error: $e');
      return null;
    }
  }

  // Pause draft
  Future<Draft?> pauseDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/pause'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Pause draft error: $e');
      return null;
    }
  }

  // Resume draft
  Future<Draft?> resumeDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/resume'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Resume draft error: $e');
      return null;
    }
  }

  // Reset draft
  Future<Draft?> resetDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/reset'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Reset draft error: $e');
      return null;
    }
  }

  // Update draft settings
  Future<Draft?> updateDraftSettings({
    required String token,
    required int draftId,
    String? draftType,
    bool? thirdRoundReversal,
    int? pickTimeSeconds,
    int? rounds,
    Map<String, dynamic>? settings,
    String? timerMode,
    int? teamTimeBudgetSeconds,
    // Auction-specific
    int? startingBudget,
    int? minBid,
    int? nominationsPerManager,
    int? nominationTimerHours,
    bool? reserveBudgetPerSlot,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/settings'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          if (draftType != null) 'draft_type': draftType,
          if (thirdRoundReversal != null) 'third_round_reversal': thirdRoundReversal,
          if (pickTimeSeconds != null) 'pick_time_seconds': pickTimeSeconds,
          if (rounds != null) 'rounds': rounds,
          if (settings != null) 'settings': settings,
          if (timerMode != null) 'timer_mode': timerMode,
          if (teamTimeBudgetSeconds != null) 'team_time_budget_seconds': teamTimeBudgetSeconds,
          if (startingBudget != null) 'starting_budget': startingBudget,
          if (minBid != null) 'min_bid': minBid,
          if (nominationsPerManager != null) 'nominations_per_manager': nominationsPerManager,
          if (nominationTimerHours != null) 'nomination_timer_hours': nominationTimerHours,
          if (reserveBudgetPerSlot != null) 'reserve_budget_per_slot': reserveBudgetPerSlot,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Draft.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Update draft settings error: $e');
      return null;
    }
  }

  // Make a draft pick
  Future<Map<String, dynamic>?> makePick({
    required String token,
    required int draftId,
    required int rosterId,
    required int playerId,
    bool isAutoPick = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/pick'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'roster_id': rosterId,
          'player_id': playerId,
          'is_auto_pick': isAutoPick,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'pick': DraftPick.fromJson(data['data']['pick']),
          'draft': Draft.fromJson(data['data']['draft']),
        };
      }
      return null;
    } catch (e) {
      debugPrint('Make pick error: $e');
      return null;
    }
  }

  // Get all picks for a draft
  Future<List<DraftPick>> getDraftPicks(
    {required String token, required int draftId, bool withDetails = true}
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/drafts/$draftId/picks?withDetails=$withDetails'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final picksData = data['data'] as List;
        return picksData.map((json) => DraftPick.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get draft picks error: $e');
      return [];
    }
  }

  // Get available players for draft
  Future<List<Player>> getAvailablePlayers(
    {required String token, required int draftId, String? position, String? team, String? search}
  ) async {
    try {
      final queryParams = <String, String>{};
      if (position != null) queryParams['position'] = position;
      if (team != null) queryParams['team'] = team;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse(
              '${ApiConfig.baseUrl}/api/v1/drafts/$draftId/players/available')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final playersData = data['data'] as List;
        return playersData.map((json) => Player.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get available players error: $e');
      return [];
    }
  }

  // Get chat messages
  Future<List<DraftChatMessage>> getChatMessages(
    {required String token, required int draftId, int limit = 100}
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/chat?limit=$limit'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messagesData = data['data'] as List;
        return messagesData
            .map((json) => DraftChatMessage.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get chat messages error: $e');
      return [];
    }
  }

  // Send chat message
  Future<DraftChatMessage?> sendChatMessage({
    required String token,
    required int draftId,
    required int userId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/chat'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'user_id': userId,
          'message': message,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return DraftChatMessage.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Send chat message error: $e');
      return null;
    }
  }

  // Sync players from Sleeper API (admin only)
  Future<bool> syncPlayers(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/players/sync'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Sync players error: $e');
      return false;
    }
  }

  // Get all players
  Future<List<Player>> getPlayers({
    String? position,
    String? team,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (position != null) queryParams['position'] = position;
      if (team != null) queryParams['team'] = team;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/players')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final playersData = data['data'] as List;
        return playersData.map((json) => Player.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get players error: $e');
      return [];
    }
  }

  // Adjust roster time (commissioner only, chess timer mode)
  Future<bool> adjustRosterTime({
    required String token,
    required int draftId,
    required int rosterId,
    required int adjustmentSeconds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/drafts/$draftId/adjust-time'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'roster_id': rosterId,
          'adjustment_seconds': adjustmentSeconds,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Adjust roster time error: $e');
      return false;
    }
  }
}
