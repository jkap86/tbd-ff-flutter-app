import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/matchup_model.dart';
import '../config/api_config.dart';

class MatchupService {
  /// Get all matchups for a league
  Future<List<Matchup>?> getMatchupsByLeague({
    required String token,
    required int leagueId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/matchups/league/$leagueId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> matchupsJson = data['data'];
          return matchupsJson.map((json) => Matchup.fromJson(json)).toList();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting matchups by league: $e');
      return null;
    }
  }

  /// Get matchups for a specific week (auto-updates scores)
  Future<List<Matchup>?> getMatchupsByWeek({
    required String token,
    required int leagueId,
    required int week,
    String? season,
    String seasonType = 'regular',
  }) async {
    try {
      // Build URL with query parameters for auto-update
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/matchups/league/$leagueId/week/$week')
          .replace(queryParameters: {
        if (season != null) 'season': season,
        'season_type': seasonType,
      });

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> matchupsJson = data['data'];
          return matchupsJson.map((json) => Matchup.fromJson(json)).toList();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting matchups by week: $e');
      return null;
    }
  }

  /// Generate matchups for a week (Commissioner only)
  Future<List<Matchup>?> generateMatchupsForWeek({
    required String token,
    required int leagueId,
    required int week,
    required String season,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/matchups/league/$leagueId/week/$week/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'season': season,
        }),
      );

      debugPrint('Generate matchups response: ${response.statusCode}');
      debugPrint('Generate matchups body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> matchupsJson = data['data'];
          return matchupsJson.map((json) => Matchup.fromJson(json)).toList();
        }
      } else {
        debugPrint('Failed to generate matchups: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('Error generating matchups: $e');
      return null;
    }
  }

  /// Update scores for a week (syncs from Sleeper and calculates)
  Future<bool> updateScoresForWeek({
    required String token,
    required int leagueId,
    required int week,
    required String season,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/matchups/league/$leagueId/week/$week/update-scores'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'season': season,
          'season_type': seasonType,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating scores: $e');
      return false;
    }
  }

  /// Get detailed matchup information with rosters and players
  Future<Map<String, dynamic>?> getMatchupDetails({
    required int matchupId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/matchups/$matchupId/details'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting matchup details: $e');
      return null;
    }
  }

  /// Get detailed matchup information with player scores
  Future<Map<String, dynamic>?> getMatchupScores({
    required int matchupId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/matchups/$matchupId/scores'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting matchup scores: $e');
      return null;
    }
  }
}
