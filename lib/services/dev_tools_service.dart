import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/roster_model.dart';

class DevToolsService {
  // Test user credentials
  static const List<Map<String, String>> testUsers = [
    {'username': 'test1', 'password': 'password'},
    {'username': 'test2', 'password': 'password'},
    {'username': 'test3', 'password': 'password'},
  ];

  /// Add all test users to a league
  static Future<Map<String, dynamic>> addTestUsersToLeague({
    required int leagueId,
    required String currentUserToken,
  }) async {
    final results = <String, dynamic>{
      'success': [],
      'failed': [],
      'errors': [],
    };

    for (final testUser in testUsers) {
      try {
        debugPrint('[DevTools] Processing ${testUser['username']}...');

        // Step 1: Login as test user to get their token
        final loginResponse = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
          headers: ApiConfig.headers,
          body: jsonEncode({
            'username': testUser['username'],
            'password': testUser['password'],
          }),
        );

        if (loginResponse.statusCode != 200) {
          results['failed'].add(testUser['username']);
          results['errors'].add('${testUser['username']}: Login failed - ${loginResponse.body}');
          debugPrint('[DevTools] Login failed for ${testUser['username']}: ${loginResponse.statusCode}');
          continue;
        }

        final loginData = jsonDecode(loginResponse.body);
        final testUserToken = loginData['data']['token'];
        final userId = loginData['data']['user']['id'];

        debugPrint('[DevTools] ${testUser['username']} logged in successfully (ID: $userId)');

        // Step 2: Join the league with test user's token
        final joinResponse = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/leagues/$leagueId/join'),
          headers: {
            ...ApiConfig.headers,
            'Authorization': 'Bearer $testUserToken',
          },
          body: jsonEncode({
            'team_name': '${testUser['username']} Team',
          }),
        );

        if (joinResponse.statusCode == 201) {
          final joinData = jsonDecode(joinResponse.body);
          results['success'].add({
            'username': testUser['username'],
            'roster': Roster.fromJson(joinData['data']),
          });
          debugPrint('[DevTools] ${testUser['username']} joined league successfully');
        } else if (joinResponse.statusCode == 400 &&
                   joinResponse.body.contains('already in this league')) {
          results['failed'].add(testUser['username']);
          results['errors'].add('${testUser['username']}: Already in league');
          debugPrint('[DevTools] ${testUser['username']} already in league');
        } else {
          results['failed'].add(testUser['username']);
          results['errors'].add('${testUser['username']}: Join failed - ${joinResponse.body}');
          debugPrint('[DevTools] Join failed for ${testUser['username']}: ${joinResponse.statusCode}');
        }

      } catch (e) {
        results['failed'].add(testUser['username']);
        results['errors'].add('${testUser['username']}: Exception - $e');
        debugPrint('[DevTools] Exception for ${testUser['username']}: $e');
      }
    }

    debugPrint('[DevTools] Results: ${results['success'].length} success, ${results['failed'].length} failed');
    return results;
  }

  /// Quick login as a test user (for testing multiple accounts)
  static Future<Map<String, dynamic>?> quickLoginAsTestUser({
    required String username,
  }) async {
    try {
      final testUser = testUsers.firstWhere(
        (user) => user['username'] == username,
        orElse: () => <String, String>{},
      );

      if (testUser.isEmpty) {
        debugPrint('[DevTools] Test user $username not found');
        return null;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'username': testUser['username'],
          'password': testUser['password'],
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      }

      return null;
    } catch (e) {
      debugPrint('[DevTools] Quick login error: $e');
      return null;
    }
  }
}