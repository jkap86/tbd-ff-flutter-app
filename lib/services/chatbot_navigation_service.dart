import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/create_league_screen.dart';
import '../screens/league_details_screen.dart';
import '../screens/draft_room_screen.dart';
import '../screens/roster_details_screen.dart';
import '../screens/trades_screen.dart';
import '../screens/waivers/waivers_hub_screen.dart';
import '../screens/profile_screen.dart';

/// Service for handling deep link navigation from chatbot responses
///
/// This service parses deep link strings from chatbot responses and navigates
/// users to the appropriate screens within the app. It handles parameter
/// extraction (like league IDs, roster IDs) and ensures the chatbot is closed
/// before navigation occurs.
///
/// Example usage:
/// ```dart
/// final navService = ChatbotNavigationService(context);
/// navService.navigate('/league/123/draft'); // Navigate to draft room for league 123
/// ```
class ChatbotNavigationService {
  final BuildContext context;

  ChatbotNavigationService(this.context);

  /// Navigate to a screen based on a deep link string
  ///
  /// Supported deep link patterns:
  /// - `/home` - Navigate to home screen
  /// - `/leagues/create` - Navigate to create league screen
  /// - `/league/:id` - Navigate to league details (requires league ID)
  /// - `/league/:id/draft` - Navigate to draft room (requires league ID)
  /// - `/roster/:id` - Navigate to roster details (requires roster ID)
  /// - `/trades` - Navigate to trades screen
  /// - `/waivers` - Navigate to waivers screen
  /// - `/profile` - Navigate to profile screen
  ///
  /// Returns `true` if navigation was successful, `false` otherwise
  bool navigate(String? deepLink) {
    if (deepLink == null || deepLink.isEmpty) {
      debugPrint('ChatbotNavigationService: No deep link provided');
      return false;
    }

    debugPrint('ChatbotNavigationService: Processing deep link: $deepLink');

    // Parse the route and extract parameters
    final route = _parseRoute(deepLink);

    if (route == null) {
      debugPrint('ChatbotNavigationService: Failed to parse route');
      return false;
    }

    debugPrint(
        'ChatbotNavigationService: Parsed route - path: ${route.path}, params: ${route.params}');

    // Close chatbot first (pop the current dialog/screen)
    // Using a delayed pop to ensure the navigation context is valid
    Future.microtask(() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    // Navigate to the appropriate destination
    return _navigateToRoute(route);
  }

  /// Navigate to the parsed route
  bool _navigateToRoute(_ParsedRoute route) {
    try {
      switch (route.path) {
        case '/home':
          _navigateToHome();
          return true;

        case '/leagues/create':
          _navigateToCreateLeague();
          return true;

        case '/league/:id':
          final leagueId = route.params['id'];
          if (leagueId != null) {
            _navigateToLeagueDetails(leagueId);
            return true;
          }
          debugPrint('ChatbotNavigationService: Missing league ID');
          return false;

        case '/league/:id/draft':
          final leagueId = route.params['id'];
          if (leagueId != null) {
            _navigateToDraftRoom(leagueId);
            return true;
          }
          debugPrint('ChatbotNavigationService: Missing league ID for draft');
          return false;

        case '/roster/:id':
          final rosterId = route.params['id'];
          if (rosterId != null) {
            _navigateToRosterDetails(rosterId);
            return true;
          }
          debugPrint('ChatbotNavigationService: Missing roster ID');
          return false;

        case '/trades':
          _navigateToTrades();
          return true;

        case '/waivers':
          _navigateToWaivers();
          return true;

        case '/profile':
          _navigateToProfile();
          return true;

        default:
          debugPrint(
              'ChatbotNavigationService: Unknown route path: ${route.path}');
          return false;
      }
    } catch (e) {
      debugPrint('ChatbotNavigationService: Navigation error: $e');
      return false;
    }
  }

  /// Parse a deep link string into a route with parameters
  ///
  /// Examples:
  /// - `/home` -> path: `/home`, params: {}
  /// - `/league/123` -> path: `/league/:id`, params: {id: 123}
  /// - `/league/456/draft` -> path: `/league/:id/draft`, params: {id: 456}
  _ParsedRoute? _parseRoute(String deepLink) {
    // Remove leading/trailing slashes and whitespace
    final cleanLink = deepLink.trim().replaceAll(RegExp(r'^/+|/+$'), '');

    if (cleanLink.isEmpty) {
      return null;
    }

    final segments = cleanLink.split('/');

    // Match routes based on segment patterns
    if (segments.length == 1) {
      switch (segments[0]) {
        case 'home':
          return _ParsedRoute('/home', {});
        case 'trades':
          return _ParsedRoute('/trades', {});
        case 'waivers':
          return _ParsedRoute('/waivers', {});
        case 'profile':
          return _ParsedRoute('/profile', {});
      }
    } else if (segments.length == 2) {
      if (segments[0] == 'leagues' && segments[1] == 'create') {
        return _ParsedRoute('/leagues/create', {});
      } else if (segments[0] == 'league') {
        // Parse league ID
        final leagueId = int.tryParse(segments[1]);
        if (leagueId != null) {
          return _ParsedRoute('/league/:id', {'id': leagueId});
        }
      } else if (segments[0] == 'roster') {
        // Parse roster ID
        final rosterId = int.tryParse(segments[1]);
        if (rosterId != null) {
          return _ParsedRoute('/roster/:id', {'id': rosterId});
        }
      }
    } else if (segments.length == 3) {
      if (segments[0] == 'league' && segments[2] == 'draft') {
        // Parse league ID for draft
        final leagueId = int.tryParse(segments[1]);
        if (leagueId != null) {
          return _ParsedRoute('/league/:id/draft', {'id': leagueId});
        }
      }
    }

    debugPrint('ChatbotNavigationService: Could not parse deep link: $deepLink');
    return null;
  }

  // Navigation helper methods

  void _navigateToHome() {
    // Navigate to home and clear the navigation stack
    Future.microtask(() {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    });
  }

  void _navigateToCreateLeague() {
    Future.microtask(() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CreateLeagueScreen()),
      );
    });
  }

  void _navigateToLeagueDetails(int leagueId) {
    Future.microtask(() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LeagueDetailsScreen(leagueId: leagueId),
        ),
      );
    });
  }

  void _navigateToDraftRoom(int leagueId) {
    // Note: DraftRoomScreen requires leagueName which we don't have context for
    // Navigate to league details instead, where user can access the draft
    Future.microtask(() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LeagueDetailsScreen(leagueId: leagueId),
        ),
      );
    });
  }

  void _navigateToRosterDetails(int rosterId) {
    // Note: RosterDetailsScreen requires rosterName which we don't have context for
    // Navigate to home instead - user will need to select league/roster manually
    _navigateToHome();
  }

  void _navigateToTrades() {
    // Note: TradesScreen requires leagueId which we don't have context for
    // Navigate to home where user can select their league
    _navigateToHome();
  }

  void _navigateToWaivers() {
    // Note: WaiversHubScreen requires leagueId and userRoster which we don't have context for
    // Navigate to home where user can select their league
    _navigateToHome();
  }

  void _navigateToProfile() {
    Future.microtask(() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    });
  }
}

/// Internal class representing a parsed route with parameters
class _ParsedRoute {
  final String path;
  final Map<String, dynamic> params;

  _ParsedRoute(this.path, this.params);

  @override
  String toString() => 'ParsedRoute(path: $path, params: $params)';
}
