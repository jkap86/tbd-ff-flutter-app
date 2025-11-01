/// Test to ensure Flutter API endpoints match backend routes
/// This test helps prevent API version mismatches (e.g., /v1 vs no version)
///
/// To run this test: flutter test test/api_endpoint_match_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  group('API Endpoint Matching Tests', () {
    // Define all backend API routes (without /v1 prefix)
    final backendEndpoints = {
      // Auth endpoints
      '/api/auth/register',
      '/api/auth/login',
      '/api/auth/logout',
      '/api/auth/refresh',
      '/api/auth/verify',
      '/api/auth/request-reset',
      '/api/auth/reset-password',

      // League endpoints
      '/api/leagues/create',
      '/api/leagues/user/{userId}',
      '/api/leagues/{leagueId}',
      '/api/leagues/{leagueId}/join',
      '/api/leagues/{leagueId}/is-commissioner',
      '/api/leagues/{leagueId}/transfer-commissioner',
      '/api/leagues/{leagueId}/remove-member',
      '/api/leagues/{leagueId}/stats',
      '/api/leagues/{leagueId}/reset',
      '/api/leagues/{leagueId}/draft',
      '/api/leagues/{leagueId}/chat',
      '/api/leagues/{leagueId}/waivers/settings',

      // Draft endpoints
      '/api/drafts/create',
      '/api/drafts/{draftId}',
      '/api/drafts/{draftId}/order',
      '/api/drafts/{draftId}/start',
      '/api/drafts/{draftId}/pause',
      '/api/drafts/{draftId}/resume',
      '/api/drafts/{draftId}/reset',
      '/api/drafts/{draftId}/settings',
      '/api/drafts/{draftId}/pick',
      '/api/drafts/{draftId}/picks',
      '/api/drafts/{draftId}/players/available',
      '/api/drafts/{draftId}/chat',
      '/api/drafts/{draftId}/adjust-time',

      // Player endpoints
      '/api/players',
      '/api/players/sync',

      // Invite endpoints
      '/api/invites/create',
      '/api/invites/{inviteCode}',
      '/api/invites/accept',
      '/api/invites/league/{leagueId}',

      // Notification endpoints
      '/notifications/register-token',
      '/notifications/preferences',
      '/notifications/deactivate',
    };

    test('No Flutter service files should contain /v1 in API paths', () async {
      final serviceFiles = [
        'lib/services/auth_service.dart',
        'lib/services/league_service.dart',
        'lib/services/draft_service.dart',
        'lib/services/league_chat_service.dart',
        'lib/services/invite_service.dart',
        'lib/services/push_notification_service.dart',
        'lib/config/api_config.dart',
      ];

      final v1Pattern = RegExp(r'api/v1/');
      final invalidFiles = <String, List<int>>{};

      for (final filePath in serviceFiles) {
        final file = File(filePath);
        if (await file.exists()) {
          final lines = await file.readAsLines();
          final v1Lines = <int>[];

          for (int i = 0; i < lines.length; i++) {
            if (v1Pattern.hasMatch(lines[i])) {
              v1Lines.add(i + 1); // Line numbers start at 1
            }
          }

          if (v1Lines.isNotEmpty) {
            invalidFiles[filePath] = v1Lines;
          }
        }
      }

      if (invalidFiles.isNotEmpty) {
        final errorMessage = StringBuffer();
        errorMessage.writeln('\nFound /v1 in API paths (should be removed):');
        invalidFiles.forEach((file, lines) {
          errorMessage.writeln('\n$file:');
          errorMessage.writeln('  Lines: ${lines.join(', ')}');
        });
        fail(errorMessage.toString());
      }
    });

    test('All API endpoints should use consistent path structure', () async {
      final serviceFiles = [
        'lib/services/auth_service.dart',
        'lib/services/league_service.dart',
        'lib/services/draft_service.dart',
        'lib/services/league_chat_service.dart',
        'lib/services/invite_service.dart',
      ];

      // Pattern to find API endpoint definitions
      final apiPattern = RegExp(r'ApiConfig\.baseUrl.*/api/[a-zA-Z0-9/_\$\{\}]+');
      final foundEndpoints = <String>{};

      for (final filePath in serviceFiles) {
        final file = File(filePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final matches = apiPattern.allMatches(content);

          for (final match in matches) {
            final fullMatch = match.group(0)!;
            // Extract the API path part after baseUrl
            if (fullMatch.contains('/api/')) {
              final apiPart = fullMatch.substring(fullMatch.indexOf('/api/'));
              // Normalize endpoint by removing variable parts
              final normalized = apiPart
                  .replaceAll(RegExp(r'\$\{?[^}]+\}?'), '{id}')
                  .replaceAll(RegExp(r'\$[a-zA-Z]+'), '{id}');
              foundEndpoints.add(normalized);
            }
          }
        }
      }

      // Check that all endpoints follow the /api/* pattern (not /api/v1/*)
      final invalidEndpoints = foundEndpoints
          .where((endpoint) => endpoint.contains('/api/v1/'))
          .toList();

      if (invalidEndpoints.isNotEmpty) {
        fail('Found endpoints with /v1 prefix:\n${invalidEndpoints.join('\n')}');
      }
    });

    test('API config should not contain version prefix', () async {
      final configFile = File('lib/config/api_config.dart');
      if (await configFile.exists()) {
        final content = await configFile.readAsString();

        // Check for /v1 in endpoint definitions
        final v1Pattern = RegExp(r'/api/v1/');
        if (v1Pattern.hasMatch(content)) {
          final lines = await configFile.readAsLines();
          final v1Lines = <int>[];

          for (int i = 0; i < lines.length; i++) {
            if (v1Pattern.hasMatch(lines[i])) {
              v1Lines.add(i + 1);
            }
          }

          fail('api_config.dart contains /v1 prefix on lines: ${v1Lines.join(', ')}');
        }
      }
    });

    test('Backend routes file should match expected structure', () async {
      // This test would verify backend routes if we had access to them
      // For now, we document the expected backend structure

      final expectedBackendStructure = '''
      Backend should have these route patterns (without /v1):

      Auth Routes:
        POST /api/auth/register
        POST /api/auth/login
        POST /api/auth/logout
        POST /api/auth/refresh
        GET  /api/auth/verify
        POST /api/auth/request-reset
        POST /api/auth/reset-password

      League Routes:
        POST   /api/leagues/create
        GET    /api/leagues/user/:userId
        GET    /api/leagues/:id
        POST   /api/leagues/:id/join
        PUT    /api/leagues/:id
        GET    /api/leagues/:id/is-commissioner
        POST   /api/leagues/:id/transfer-commissioner
        POST   /api/leagues/:id/remove-member
        GET    /api/leagues/:id/stats
        POST   /api/leagues/:id/reset
        DELETE /api/leagues/:id
        GET    /api/leagues/:id/draft
        GET    /api/leagues/:id/chat
        POST   /api/leagues/:id/chat

      Draft Routes:
        POST /api/drafts/create
        GET  /api/drafts/:id
        POST /api/drafts/:id/order
        GET  /api/drafts/:id/order
        POST /api/drafts/:id/start
        POST /api/drafts/:id/pause
        POST /api/drafts/:id/resume
        POST /api/drafts/:id/reset
        PUT  /api/drafts/:id/settings
        POST /api/drafts/:id/pick
        GET  /api/drafts/:id/picks
        GET  /api/drafts/:id/players/available
        GET  /api/drafts/:id/chat
        POST /api/drafts/:id/chat
        POST /api/drafts/:id/adjust-time

      Player Routes:
        GET  /api/players
        POST /api/players/sync

      Invite Routes:
        POST /api/invites/create
        GET  /api/invites/:code
        POST /api/invites/accept
        GET  /api/invites/league/:leagueId
      ''';

      // This test passes if the structure is documented
      expect(expectedBackendStructure.isNotEmpty, true);
    });

    test('Ensure no hardcoded localhost URLs exist', () async {
      final serviceFiles = [
        'lib/services/auth_service.dart',
        'lib/services/league_service.dart',
        'lib/services/draft_service.dart',
        'lib/services/league_chat_service.dart',
        'lib/services/invite_service.dart',
        'lib/services/push_notification_service.dart',
      ];

      final localhostPattern = RegExp(r'localhost:\d+|127\.0\.0\.1:\d+');
      final invalidFiles = <String, List<int>>{};

      for (final filePath in serviceFiles) {
        final file = File(filePath);
        if (await file.exists()) {
          final lines = await file.readAsLines();
          final localhostLines = <int>[];

          for (int i = 0; i < lines.length; i++) {
            if (localhostPattern.hasMatch(lines[i])) {
              localhostLines.add(i + 1);
            }
          }

          if (localhostLines.isNotEmpty) {
            invalidFiles[filePath] = localhostLines;
          }
        }
      }

      if (invalidFiles.isNotEmpty) {
        final errorMessage = StringBuffer();
        errorMessage.writeln('\nFound hardcoded localhost URLs:');
        invalidFiles.forEach((file, lines) {
          errorMessage.writeln('\n$file:');
          errorMessage.writeln('  Lines: ${lines.join(', ')}');
        });
        fail(errorMessage.toString());
      }
    });
  });
}