import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/league_model.dart';
import '../models/roster_model.dart';

class LeagueService {
  // Create a new league
  Future<League?> createLeague({
    required String token,
    required String name,
    required String season,
    String? seasonType,
    String leagueType = 'redraft',
    int totalRosters = 12,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? scoringSettings,
    List<dynamic>? rosterPositions,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'season': season,
        'league_type': leagueType,
        'total_rosters': totalRosters,
        'settings': settings ?? {},
        'scoring_settings': scoringSettings ?? {},
        'roster_positions': rosterPositions ?? [],
      };

      if (seasonType != null) {
        body['season_type'] = seasonType;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/create'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return League.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Create league error: $e');
      return null;
    }
  }

  // Get all leagues for a user
  Future<List<League>> getUserLeagues(int userId) async {
    try {
      debugPrint('[LeagueService] Fetching leagues for user $userId');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/user/$userId'),
        headers: ApiConfig.headers,
      );

      debugPrint('[LeagueService] Response status: ${response.statusCode}');
      debugPrint('[LeagueService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leaguesData = data['data'] as List;
        debugPrint('[LeagueService] Found ${leaguesData.length} leagues');
        return leaguesData.map((json) => League.fromJson(json)).toList();
      } else {
        debugPrint('[LeagueService] Error response: ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('[LeagueService] Exception getting user leagues: $e');
      debugPrint('[LeagueService] Stack trace: $stackTrace');
      return [];
    }
  }

  // Get league details with rosters
  Future<Map<String, dynamic>?> getLeagueDetails(int leagueId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leagueData = data['data'];

        return {
          'league': League.fromJson(leagueData['league']),
          'rosters': (leagueData['rosters'] as List?)
                  ?.map((json) => Roster.fromJson(json))
                  .toList() ??
              [],
        };
      }
      return null;
    } catch (e) {
      debugPrint('Get league details error: $e');
      return null;
    }
  }

  // Join a league
  Future<Roster?> joinLeague({
    required String token,
    required int leagueId,
    String? teamName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/join'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'team_name': teamName,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Roster.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Join league error: $e');
      return null;
    }
  }

  // Update league settings
  Future<League?> updateLeagueSettings({
    required String token,
    required int leagueId,
    String? name,
    String? seasonType,
    int? totalRosters,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? scoringSettings,
    List<dynamic>? rosterPositions,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (name != null) body['name'] = name;
      if (seasonType != null) body['season_type'] = seasonType;
      if (totalRosters != null) body['total_rosters'] = totalRosters;
      if (settings != null) body['settings'] = settings;
      if (scoringSettings != null) body['scoring_settings'] = scoringSettings;
      if (rosterPositions != null) body['roster_positions'] = rosterPositions;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return League.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Update league settings error: $e');
      return null;
    }
  }

  // Check if user is commissioner
  Future<bool> isUserCommissioner({
    required String token,
    required int leagueId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/is-commissioner'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['isCommissioner'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Is commissioner check error: $e');
      return false;
    }
  }

  // Transfer commissioner role
  Future<League?> transferCommissioner({
    required String token,
    required int leagueId,
    required int newCommissionerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/leagues/$leagueId/transfer-commissioner'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'newCommissionerId': newCommissionerId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return League.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Transfer commissioner error: $e');
      return null;
    }
  }

  // Remove league member
  Future<bool> removeLeagueMember({
    required String token,
    required int leagueId,
    required int userIdToRemove,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/remove-member'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'userIdToRemove': userIdToRemove,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Remove league member error: $e');
      return false;
    }
  }

  // Get league stats
  Future<Map<String, dynamic>?> getLeagueStats({
    required String token,
    required int leagueId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/stats'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Get league stats error: $e');
      return null;
    }
  }

  /// Reset league to pre-draft status
  /// Deletes draft, clears all rosters, keeps teams intact
  Future<bool> resetLeague({
    required String token,
    required int leagueId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/reset'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Reset league error: $e');
      return false;
    }
  }

  /// Delete a league (commissioner only)
  /// Permanently deletes the league and all related data
  Future<bool> deleteLeague({
    required String token,
    required int leagueId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete league error: $e');
      return false;
    }
  }
}
