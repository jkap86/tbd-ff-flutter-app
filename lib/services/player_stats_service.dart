import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PlayerStatsService {
  // Get all player stats for a specific week
  Future<List<Map<String, dynamic>>?> getPlayerStats({
    required int season,
    required int week,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/player-stats/$season/$week?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Get player stats error: $e');
      return null;
    }
  }

  // Get stats for a specific player
  Future<Map<String, dynamic>?> getPlayerStatsById({
    required int season,
    required int week,
    required String playerId,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/player-stats/$season/$week/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get player stats by ID error: $e');
      return null;
    }
  }

  // Get all player projections for a specific week
  Future<List<Map<String, dynamic>>?> getPlayerProjections({
    required int season,
    required int week,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/player-projections/$season/$week?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Get player projections error: $e');
      return null;
    }
  }

  // Get projections for a specific player
  Future<Map<String, dynamic>?> getPlayerProjectionsById({
    required int season,
    required int week,
    required String playerId,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/player-projections/$season/$week/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get player projections by ID error: $e');
      return null;
    }
  }

  // Get full season stats (no week parameter returns full season)
  Future<Map<String, dynamic>?> getSeasonStats({
    required int season,
    required String playerId,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/player-stats/$season/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get season stats error: $e');
      return null;
    }
  }

  // Get full season projections (no week parameter returns full season)
  Future<Map<String, dynamic>?> getSeasonProjections({
    required int season,
    required String playerId,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/v1/player-projections/$season/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get season projections error: $e');
      return null;
    }
  }

  // Get bulk season stats for multiple players
  Future<Map<String, Map<String, dynamic>>?> getBulkSeasonStats({
    required int season,
    required List<String> playerIds,
    String seasonType = 'regular',
  }) async {
    try {
      if (playerIds.isEmpty) return {};

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/player-stats/bulk/$season'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player_ids': playerIds,
          'season_type': seasonType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final statsData = data['data'] as Map<String, dynamic>;

        // Convert to Map<String, Map<String, dynamic>>
        return statsData.map((key, value) =>
          MapEntry(key, value as Map<String, dynamic>)
        );
      }
      return null;
    } catch (e) {
      debugPrint('Get bulk season stats error: $e');
      return null;
    }
  }

  // Get bulk season projections for multiple players
  Future<Map<String, Map<String, dynamic>>?> getBulkSeasonProjections({
    required int season,
    required List<String> playerIds,
    String seasonType = 'regular',
  }) async {
    try {
      if (playerIds.isEmpty) return {};

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/player-projections/bulk/$season'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player_ids': playerIds,
          'season_type': seasonType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final projectionsData = data['data'] as Map<String, dynamic>;

        // Convert to Map<String, Map<String, dynamic>>
        return projectionsData.map((key, value) =>
          MapEntry(key, value as Map<String, dynamic>)
        );
      }
      return null;
    } catch (e) {
      debugPrint('Get bulk season projections error: $e');
      return null;
    }
  }

  // Get bulk projections for multiple players across a week range
  Future<Map<String, Map<String, dynamic>>?> getBulkWeekRangeProjections({
    required int season,
    required List<String> playerIds,
    required int startWeek,
    required int endWeek,
    String seasonType = 'regular',
  }) async {
    try {
      if (playerIds.isEmpty) return {};

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/player-projections/bulk/$season/weeks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player_ids': playerIds,
          'start_week': startWeek,
          'end_week': endWeek,
          'season_type': seasonType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final projectionsData = data['data'] as Map<String, dynamic>;

        // Convert to Map<String, Map<String, dynamic>>
        return projectionsData.map((key, value) =>
          MapEntry(key, value as Map<String, dynamic>)
        );
      }
      return null;
    } catch (e) {
      debugPrint('Get bulk week range projections error: $e');
      return null;
    }
  }
}
