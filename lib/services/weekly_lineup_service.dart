import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class WeeklyLineupService {
  /// Get weekly lineup with player details
  Future<Map<String, dynamic>?> getWeeklyLineup({
    required String token,
    required int rosterId,
    required int week,
    required String season,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/weekly-lineups/roster/$rosterId/week/$week/season/$season'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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
      print('Error getting weekly lineup: $e');
      return null;
    }
  }

  /// Update weekly lineup
  Future<Map<String, dynamic>?> updateWeeklyLineup({
    required String token,
    required int rosterId,
    required int week,
    required String season,
    required List<Map<String, dynamic>> starters,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/weekly-lineups/roster/$rosterId/week/$week/season/$season'),
        headers:{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'starters': starters,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error updating weekly lineup: $e');
      return null;
    }
  }
}
