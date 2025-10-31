import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class NflService {
  /// Get the current NFL week for a given season
  Future<int?> getCurrentWeek({
    required String season,
    String seasonType = 'regular',
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/nfl/current-week?season=$season&season_type=$seasonType',
        ),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['week'] as int?;
        }
      }

      debugPrint('Failed to get current week: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error getting current week: $e');
      return null;
    }
  }
}
