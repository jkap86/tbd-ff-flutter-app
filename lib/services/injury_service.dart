import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class InjuryService {
  static Future<List<dynamic>> getAllInjuries(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/injuries/all'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to fetch injuries');
      }
    } catch (error) {
      debugPrint('[InjuryService] Error fetching injuries: $error');
      rethrow;
    }
  }

  static Future<List<dynamic>> getLeagueInjuryReport(
    String token,
    int leagueId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/injuries/league/$leagueId'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to fetch league injury report');
      }
    } catch (error) {
      debugPrint('[InjuryService] Error fetching league injuries: $error');
      rethrow;
    }
  }
}
