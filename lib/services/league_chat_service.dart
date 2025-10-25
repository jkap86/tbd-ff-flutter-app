import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/league_chat_message_model.dart';

class LeagueChatService {
  // Get chat messages for a league
  Future<List<LeagueChatMessage>> getChatMessages(int leagueId,
      {int limit = 100}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/chat?limit=$limit'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messagesData = data['data'] as List;
        return messagesData
            .map((json) => LeagueChatMessage.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Get league chat messages error: $e');
      return [];
    }
  }

  // Send chat message
  Future<LeagueChatMessage?> sendChatMessage({
    required String token,
    required int leagueId,
    required int userId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/chat'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'user_id': userId,
          'message': message,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return LeagueChatMessage.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('Send league chat message error: $e');
      return null;
    }
  }
}
