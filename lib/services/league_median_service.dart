import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/league_median_settings_model.dart';

class LeagueMedianService {
  /// Get league median settings for a league
  static Future<LeagueMedianSettings?> getLeagueMedianSettings(
    String token,
    int leagueId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/league-median/league/$leagueId/settings'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LeagueMedianSettings.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Get league median settings error: $e');
      return null;
    }
  }

  /// Update league median settings
  static Future<LeagueMedianSettings?> updateLeagueMedianSettings(
    String token,
    int leagueId, {
    required bool enableLeagueMedian,
    int? medianMatchupWeekStart,
    int? medianMatchupWeekEnd,
  }) async {
    try {
      final body = <String, dynamic>{
        'enable_league_median': enableLeagueMedian,
      };

      if (medianMatchupWeekStart != null) {
        body['median_matchup_week_start'] = medianMatchupWeekStart;
      }
      if (medianMatchupWeekEnd != null) {
        body['median_matchup_week_end'] = medianMatchupWeekEnd;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/league-median/league/$leagueId/settings'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LeagueMedianSettings.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Update league median settings error: $e');
      return null;
    }
  }

  /// Generate median matchups for a week or season
  /// If week is null, generates matchups for the entire season
  /// Returns a map containing weeks_generated and matchups_created counts
  static Future<Map<String, dynamic>?> generateMedianMatchups(
    String token,
    int leagueId,
    String season, {
    int? week,
  }) async {
    try {
      final body = <String, dynamic>{
        'season': season,
      };

      if (week != null) {
        body['week'] = week;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/league-median/league/$leagueId/generate'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Generate median matchups error: $e');
      return null;
    }
  }

  /// Get median score for a specific week
  /// Returns the median score as a double, or null if not available
  static Future<double?> getWeekMedian(
    String token,
    int leagueId,
    int week,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/league-median/league/$leagueId/week/$week/median'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final medianData = data['data'];

        // Extract median_score and convert to double
        if (medianData != null && medianData['median_score'] != null) {
          return (medianData['median_score'] as num).toDouble();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Get week median error: $e');
      return null;
    }
  }

  /// Update median matchup results for a week
  /// Recalculates which teams beat/lost to the median and updates matchup results
  /// Returns true if successful, false otherwise
  static Future<bool> updateMedianResults(
    String token,
    int leagueId,
    int week,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/league-median/league/$leagueId/week/$week/update-results'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update median results error: $e');
      return false;
    }
  }
}
