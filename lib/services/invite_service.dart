import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/league_invite_model.dart';
import '../models/user_search_model.dart';

class InviteService {
  // Send league invite
  Future<bool> sendInvite({
    required String token,
    required int leagueId,
    required int invitedUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/invites/send'),
        headers: ApiConfig.getAuthHeaders(token),
        body: jsonEncode({
          'league_id': leagueId,
          'invited_user_id': invitedUserId,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Send invite error: $e');
      return false;
    }
  }

  // Get user's invites
  Future<List<LeagueInvite>> getUserInvites(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/invites/user/$userId'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final invitesData = data['data'] as List;
        return invitesData.map((json) => LeagueInvite.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get user invites error: $e');
      return [];
    }
  }

  // Accept invite
  Future<bool> acceptInvite({
    required String token,
    required int inviteId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/invites/$inviteId/accept'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Accept invite error: $e');
      return false;
    }
  }

  // Decline invite
  Future<bool> declineInvite({
    required String token,
    required int inviteId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/invites/$inviteId/decline'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Decline invite error: $e');
      return false;
    }
  }

  // Search users
  Future<List<UserSearchResult>> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/users/search?query=${Uri.encodeComponent(query)}'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final usersData = data['data'] as List;
        return usersData
            .map((json) => UserSearchResult.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Search users error: $e');
      return [];
    }
  }

  // Get public leagues
  Future<List<dynamic>> getPublicLeagues() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/public'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List;
      }
      return [];
    } catch (e) {
      debugPrint('Get public leagues error: $e');
      return [];
    }
  }
}
