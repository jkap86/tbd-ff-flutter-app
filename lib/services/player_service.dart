import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/player_model.dart';

class PlayerService {
  /// Get all players with optional filtering
  /// Used to fetch specific players by bulk search
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

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/players')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> playersJson = data['data'];
          return playersJson.map((json) => Player.fromJson(json)).toList();
        }
      }

      debugPrint('Failed to get players: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error getting players: $e');
      return [];
    }
  }

  /// Get player by ID - requires fetching all and filtering
  /// Note: Backend has getPlayerById in model but no REST endpoint for it
  Future<Player?> getPlayerById(int playerId) async {
    try {
      // For now, we'll need to fetch and filter client-side
      // In production, should add GET /api/players/:id endpoint
      final players = await getPlayers();
      return players.firstWhere(
        (p) => p.id == playerId,
        orElse: () => throw Exception('Player not found'),
      );
    } catch (e) {
      debugPrint('Error getting player by ID: $e');
      return null;
    }
  }

  /// Get multiple players by their IDs
  /// Uses bulk endpoint for efficient fetching
  Future<List<Player>> getPlayersByIds(List<int> playerIds) async {
    if (playerIds.isEmpty) return [];

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/players/bulk'),
        headers: ApiConfig.headers,
        body: json.encode({'player_ids': playerIds}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> playersJson = data['data'];
          return playersJson.map((json) => Player.fromJson(json)).toList();
        }
      }

      debugPrint('Failed to get players by IDs: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error getting players by IDs: $e');
      return [];
    }
  }
}
