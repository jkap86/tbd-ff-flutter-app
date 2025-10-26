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
      print('Get roster with players error: $e');
      return null;
    }
  }
}
