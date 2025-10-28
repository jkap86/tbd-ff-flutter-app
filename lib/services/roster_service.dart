import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class RosterService {
  // Get roster with player details
  Future<Map<String, dynamic>?> getRosterWithPlayers(
    String token,
    int rosterId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/rosters/$rosterId/players'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Get roster with players error: $e');
      return null;
    }
  }

  // Update roster lineup
  Future<Map<String, dynamic>?> updateRosterLineup(
    String token,
    int rosterId, {
    List<Map<String, dynamic>>? starters,
    List<int>? bench,
    List<int>? taxi,
    List<int>? ir,
  }) async {
    try {
      debugPrint('[RosterService] Updating lineup for roster $rosterId');
      debugPrint('[RosterService] Starters: $starters');
      debugPrint('[RosterService] Bench: $bench');

      final body = {
        if (starters != null) 'starters': starters,
        if (bench != null) 'bench': bench,
        if (taxi != null) 'taxi': taxi,
        if (ir != null) 'ir': ir,
      };

      debugPrint('[RosterService] Request body: ${jsonEncode(body)}');

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/rosters/$rosterId/lineup'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('[RosterService] Response status: ${response.statusCode}');
      debugPrint('[RosterService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('[RosterService] Update roster lineup error: $e');
      debugPrint('[RosterService] Stack trace: $stackTrace');
      return null;
    }
  }
}
