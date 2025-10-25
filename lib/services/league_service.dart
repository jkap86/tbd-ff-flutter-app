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
    String leagueType = 'redraft',
    int totalRosters = 12,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? scoringSettings,
    List<dynamic>? rosterPositions,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/create'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'name': name,
          'season': season,
          'league_type': leagueType,
          'total_rosters': totalRosters,
          'settings': settings ?? {},
          'scoring_settings': scoringSettings ?? {},
          'roster_positions': rosterPositions ?? [],
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return League.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('Create league error: $e');
      return null;
    }
  }

  // Get all leagues for a user
  Future<List<League>> getUserLeagues(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/user/$userId'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leaguesData = data['data'] as List;
        return leaguesData.map((json) => League.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get user leagues error: $e');
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
      print('Get league details error: $e');
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
      print('Join league error: $e');
      return null;
    }
  }

  // Update league settings
  Future<League?> updateLeagueSettings({
    required String token,
    required int leagueId,
    String? name,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? scoringSettings,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (name != null) body['name'] = name;
      if (settings != null) body['settings'] = settings;
      if (scoringSettings != null) body['scoring_settings'] = scoringSettings;

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
      print('Update league settings error: $e');
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
      print('Is commissioner check error: $e');
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
      print('Transfer commissioner error: $e');
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
      print('Remove league member error: $e');
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
      print('Get league stats error: $e');
      return null;
    }
  }
}
