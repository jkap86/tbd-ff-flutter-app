import 'package:flutter/foundation.dart';
import '../models/league_model.dart';
import '../models/roster_model.dart';
import '../services/league_service.dart';

enum LeagueStatus {
  initial,
  loading,
  loaded,
  error,
}

class LeagueProvider with ChangeNotifier {
  final LeagueService _leagueService = LeagueService();

  LeagueStatus _status = LeagueStatus.initial;
  List<League> _userLeagues = [];
  League? _selectedLeague;
  List<Roster> _selectedLeagueRosters = [];
  String? _errorMessage;

  // Getters
  LeagueStatus get status => _status;
  List<League> get userLeagues => _userLeagues;
  League? get selectedLeague => _selectedLeague;
  List<Roster> get selectedLeagueRosters => _selectedLeagueRosters;
  String? get errorMessage => _errorMessage;

  // Create a new league
  Future<bool> createLeague({
    required String token,
    required String name,
    required String season,
    String seasonType = 'regular',
    int totalRosters = 12,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? scoringSettings,
    List<dynamic>? rosterPositions,
  }) async {
    _status = LeagueStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final league = await _leagueService.createLeague(
        token: token,
        name: name,
        season: season,
        seasonType: seasonType,
        totalRosters: totalRosters,
        settings: settings,
        scoringSettings: scoringSettings,
        rosterPositions: rosterPositions,
      );

      if (league != null) {
        _userLeagues.insert(0, league);
        _status = LeagueStatus.loaded;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to create league';
        _status = LeagueStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error creating league: ${e.toString()}';
      _status = LeagueStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Load user's leagues
  Future<void> loadUserLeagues(int userId) async {
    _status = LeagueStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final leagues = await _leagueService.getUserLeagues(userId);
      _userLeagues = leagues;
      _status = LeagueStatus.loaded;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading leagues: ${e.toString()}';
      _status = LeagueStatus.error;
      notifyListeners();
    }
  }

  // Load league details with rosters
  Future<void> loadLeagueDetails(int leagueId) async {
    _status = LeagueStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final details = await _leagueService.getLeagueDetails(leagueId);

      if (details != null) {
        _selectedLeague = details['league'];
        _selectedLeagueRosters = details['rosters'];
        _status = LeagueStatus.loaded;
        notifyListeners();
      } else {
        _errorMessage = 'Failed to load league details';
        _status = LeagueStatus.error;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error loading league details: ${e.toString()}';
      _status = LeagueStatus.error;
      notifyListeners();
    }
  }

  // Join a league
  Future<bool> joinLeague({
    required String token,
    required int leagueId,
    String? teamName,
  }) async {
    _status = LeagueStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final roster = await _leagueService.joinLeague(
        token: token,
        leagueId: leagueId,
        teamName: teamName,
      );

      if (roster != null) {
        _status = LeagueStatus.loaded;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to join league';
        _status = LeagueStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error joining league: ${e.toString()}';
      _status = LeagueStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear selected league
  void clearSelectedLeague() {
    _selectedLeague = null;
    _selectedLeagueRosters = [];
    notifyListeners();
  }
}
