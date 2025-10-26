import 'package:flutter/foundation.dart';
import '../models/matchup_model.dart';
import '../services/matchup_service.dart';

enum MatchupStatus { idle, loading, loaded, error }

class MatchupProvider with ChangeNotifier {
  final MatchupService _matchupService = MatchupService();

  MatchupStatus _status = MatchupStatus.idle;
  List<Matchup> _matchups = [];
  String? _errorMessage;
  int? _currentWeek;

  MatchupStatus get status => _status;
  List<Matchup> get matchups => _matchups;
  String? get errorMessage => _errorMessage;
  int? get currentWeek => _currentWeek;

  /// Load all matchups for a league
  Future<void> loadMatchupsByLeague({
    required String token,
    required int leagueId,
  }) async {
    _status = MatchupStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final matchups = await _matchupService.getMatchupsByLeague(
        token: token,
        leagueId: leagueId,
      );

      if (matchups != null) {
        _matchups = matchups;
        _status = MatchupStatus.loaded;
      } else {
        // Treat null response as empty matchups list (no error)
        _matchups = [];
        _status = MatchupStatus.loaded;
      }
    } catch (e) {
      _errorMessage = 'Error loading matchups: ${e.toString()}';
      _status = MatchupStatus.error;
    }

    notifyListeners();
  }

  /// Load matchups for a specific week
  Future<void> loadMatchupsByWeek({
    required String token,
    required int leagueId,
    required int week,
  }) async {
    _status = MatchupStatus.loading;
    _errorMessage = null;
    _currentWeek = week;
    notifyListeners();

    try {
      final matchups = await _matchupService.getMatchupsByWeek(
        token: token,
        leagueId: leagueId,
        week: week,
      );

      if (matchups != null) {
        _matchups = matchups;
        _status = MatchupStatus.loaded;
      } else {
        // Treat null response as empty matchups list (no error)
        _matchups = [];
        _status = MatchupStatus.loaded;
      }
    } catch (e) {
      _errorMessage = 'Error loading matchups: ${e.toString()}';
      _status = MatchupStatus.error;
    }

    notifyListeners();
  }

  /// Generate matchups for a week
  Future<bool> generateMatchups({
    required String token,
    required int leagueId,
    required int week,
    required String season,
  }) async {
    try {
      print('[MatchupProvider] Generating matchups for league $leagueId, week $week, season: "$season"');

      final matchups = await _matchupService.generateMatchupsForWeek(
        token: token,
        leagueId: leagueId,
        week: week,
        season: season,
      );

      if (matchups != null) {
        _matchups = matchups;
        _currentWeek = week;
        _status = MatchupStatus.loaded;
        notifyListeners();
        return true;
      }

      print('[MatchupProvider] Generate matchups returned null');
      return false;
    } catch (e) {
      _errorMessage = 'Error generating matchups: ${e.toString()}';
      print('[MatchupProvider] Error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Generate matchups for all regular season weeks
  Future<bool> generateAllRegularSeasonMatchups({
    required String token,
    required int leagueId,
    required String season,
    required int startWeek,
    required int playoffWeekStart,
  }) async {
    try {
      print('[MatchupProvider] Generating all regular season matchups from week $startWeek to ${playoffWeekStart - 1}');

      int successCount = 0;
      int totalWeeks = playoffWeekStart - startWeek;

      for (int week = startWeek; week < playoffWeekStart; week++) {
        final success = await generateMatchups(
          token: token,
          leagueId: leagueId,
          week: week,
          season: season,
        );

        if (success) {
          successCount++;
        }
      }

      // Reload all matchups to get the full list
      await loadMatchupsByLeague(
        token: token,
        leagueId: leagueId,
      );

      return successCount == totalWeeks;
    } catch (e) {
      _errorMessage = 'Error generating all matchups: ${e.toString()}';
      print('[MatchupProvider] Error generating all: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update scores for current week
  Future<bool> updateScores({
    required String token,
    required int leagueId,
    required int week,
    required String season,
    String seasonType = 'regular',
  }) async {
    try {
      final success = await _matchupService.updateScoresForWeek(
        token: token,
        leagueId: leagueId,
        week: week,
        season: season,
        seasonType: seasonType,
      );

      if (success) {
        // Reload matchups to get updated scores
        await loadMatchupsByWeek(
          token: token,
          leagueId: leagueId,
          week: week,
        );
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error updating scores: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Get matchups grouped by week
  Map<int, List<Matchup>> get matchupsByWeek {
    final Map<int, List<Matchup>> grouped = {};
    for (final matchup in _matchups) {
      grouped.putIfAbsent(matchup.week, () => []).add(matchup);
    }
    return grouped;
  }

  /// Get available weeks
  List<int> get availableWeeks {
    final weeks = _matchups.map((m) => m.week).toSet().toList();
    weeks.sort();
    return weeks;
  }

  void clearMatchups() {
    _matchups = [];
    _currentWeek = null;
    _status = MatchupStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
