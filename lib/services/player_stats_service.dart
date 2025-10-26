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
            '${ApiConfig.baseUrl}/api/player-stats/$season/$week?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      print('Get player stats error: $e');
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
            '${ApiConfig.baseUrl}/api/player-stats/$season/$week/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get player stats by ID error: $e');
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
            '${ApiConfig.baseUrl}/api/player-projections/$season/$week?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      print('Get player projections error: $e');
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
            '${ApiConfig.baseUrl}/api/player-projections/$season/$week/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get player projections by ID error: $e');
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
            '${ApiConfig.baseUrl}/api/player-stats/$season/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get season stats error: $e');
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
            '${ApiConfig.baseUrl}/api/player-projections/$season/$playerId?season_type=$seasonType'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get season projections error: $e');
      return null;
    }
  }
}
