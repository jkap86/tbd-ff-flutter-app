import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConfig {
  // Production URL
  static const String _productionUrl = 'https://tbd-ff-6abbe03bd5b6.herokuapp.com';

  // Development URLs
  static const String _devUrlWeb = 'http://localhost:3000';
  static const String _devUrlAndroid = 'http://10.0.2.2:3000'; // Android emulator
  static const String _devUrlIOS = 'http://localhost:3000'; // iOS simulator

  // Automatically detect environment and platform
  static String get baseUrl {
    // Production mode - use production URL
    if (kReleaseMode) {
      return _productionUrl;
    }

    // Development mode - detect platform
    if (kIsWeb) {
      return _devUrlWeb;
    }

    // Mobile platforms
    try {
      if (Platform.isAndroid) {
        return _devUrlAndroid;
      } else if (Platform.isIOS) {
        return _devUrlIOS;
      } else {
        // Fallback for other platforms (desktop, etc.)
        return _devUrlWeb;
      }
    } catch (e) {
      // If Platform is not available (shouldn't happen), default to web
      return _devUrlWeb;
    }
  }

  // Override for physical devices (set this manually if testing on real device)
  // Example: ApiConfig.overrideBaseUrl = 'http://192.168.1.100:3000';
  static String? overrideBaseUrl;

  static String get effectiveBaseUrl => overrideBaseUrl ?? baseUrl;

  // API endpoints - Auth
  static String get register => '$effectiveBaseUrl/api/v1/auth/register';
  static String get login => '$effectiveBaseUrl/api/v1/auth/login';
  static String get profile => '$effectiveBaseUrl/api/v1/profile';

  // API endpoints - Leagues
  static String get leaguesCreate => '$effectiveBaseUrl/api/v1/leagues/create';
  static String get leaguesPublic => '$effectiveBaseUrl/api/v1/leagues/public';
  static String get leaguesUser => '$effectiveBaseUrl/api/v1/leagues/user';
  static String get leaguesDetail => '$effectiveBaseUrl/api/v1/leagues';
  static String get leaguesJoin => '$effectiveBaseUrl/api/v1/leagues';
  static String get leaguesUpdate => '$effectiveBaseUrl/api/v1/leagues';
  static String get leaguesIsCommissioner => '$effectiveBaseUrl/api/v1/leagues';
  static String get leaguesTransferCommissioner => '$effectiveBaseUrl/api/v1/leagues';
  static String get leaguesRemoveMember => '$effectiveBaseUrl/api/v1/leagues';
  static String get leaguesStats => '$effectiveBaseUrl/api/v1/leagues';

  // API endpoints - Invites
  static String get invitesSend => '$effectiveBaseUrl/api/v1/invites/send';
  static String get invitesUser => '$effectiveBaseUrl/api/v1/invites/user';
  static String get invitesAccept => '$effectiveBaseUrl/api/v1/invites';
  static String get invitesDecline => '$effectiveBaseUrl/api/v1/invites';

  // Headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
      };

  static Map<String, String> getAuthHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // Debug helper to print current configuration
  static void printConfig() {
    if (kDebugMode) {
      debugPrint('🌐 API Configuration:');
      debugPrint('   Mode: ${kReleaseMode ? "PRODUCTION" : "DEVELOPMENT"}');
      debugPrint('   Platform: ${_getPlatformName()}');
      debugPrint('   Base URL: $effectiveBaseUrl');
      if (overrideBaseUrl != null) {
        debugPrint('   ⚠️  URL Override Active: $overrideBaseUrl');
      }
    }
  }

  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isLinux) return 'Linux';
    } catch (e) {
      // Platform not available
    }
    return 'Unknown';
  }
}
