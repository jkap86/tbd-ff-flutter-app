import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/auction_model.dart';
import '../models/player_model.dart';
import '../models/draft_model.dart';
import '../models/roster_model.dart';
import '../services/auction_service.dart';
import '../services/socket_service.dart';
import '../services/draft_service.dart';
import '../services/league_service.dart';

enum AuctionStatus {
  initial,
  loading,
  loaded,
  error,
}

class AuctionProvider with ChangeNotifier {
  final AuctionService _auctionService = AuctionService();
  final SocketService _socketService = SocketService();
  final DraftService _draftService = DraftService();
  final LeagueService _leagueService = LeagueService();

  AuctionStatus _status = AuctionStatus.initial;
  List<AuctionNomination> _activeNominations = [];
  Map<int, List<AuctionBid>> _nominationBids = {}; // nominationId -> bids
  List<Player> _availablePlayers = [];
  List<ActivityItem> _activityFeed = [];
  RosterBudget? _myBudget;
  int? _myRosterId;
  Draft? _draft;
  List<Roster> _rosters = [];
  List<Map<String, dynamic>> _auctionRosters = []; // Rosters with players and budgets
  String? _errorMessage;

  // Getters
  AuctionStatus get status => _status;
  List<AuctionNomination> get activeNominations => _activeNominations;
  List<Player> get availablePlayers => _availablePlayers;
  List<ActivityItem> get activityFeed => _activityFeed;
  RosterBudget? get myBudget => _myBudget;
  Draft? get draft => _draft;
  List<Roster> get rosters => _rosters;
  List<Map<String, dynamic>> get auctionRosters => _auctionRosters;
  String? get errorMessage => _errorMessage;
  bool get isSocketConnected => _socketService.isConnected;

  List<AuctionBid> getBidsForNomination(int nominationId) {
    return _nominationBids[nominationId] ?? [];
  }

  int? get myWinningNominationsCount {
    if (_myRosterId == null) return null;
    return _activeNominations.where((n) => n.winningRosterId == _myRosterId).length;
  }

  int? get myActiveNominationsCount {
    if (_myRosterId == null) return null;
    return _activeNominations.where((n) => n.nominatingRosterId == _myRosterId).length;
  }

  // Check if I'm winning a specific nomination
  bool isMyBid(AuctionNomination nomination) {
    return _myRosterId != null && nomination.winningRosterId == _myRosterId;
  }

  // Setup socket listeners for slow auction
  void setupSlowAuctionListeners(int draftId, int myRosterId) {
    _myRosterId = myRosterId;

    // Join the auction room
    _socketService.joinAuction(draftId: draftId, rosterId: myRosterId);

    _socketService.onActiveNominations = (data) {
      debugPrint('Received active_nominations: $data');
      _activeNominations = (data as List)
          .map((n) => AuctionNomination.fromJson(n))
          .toList();
      notifyListeners();
    };

    _socketService.onPlayerNominated = (data) {
      debugPrint('Received player_nominated: $data');
      final nomination = AuctionNomination.fromJson(data);
      _activeNominations.add(nomination);
      _nominationBids[nomination.id] = [];

      // Remove from available players
      _availablePlayers.removeWhere((p) => p.playerId == nomination.playerId);

      // Add to activity feed
      final nominatorText = nomination.nominatingTeamName != null
          ? ' by ${nomination.nominatingTeamName}'
          : '';
      _activityFeed.insert(
        0,
        ActivityItem(
          type: 'nomination',
          description: '${nomination.playerName} nominated$nominatorText',
          timestamp: DateTime.now(),
          playerId: nomination.playerId,
          playerName: nomination.playerName,
        ),
      );

      notifyListeners();
    };

    _socketService.onBidPlaced = (data) {
      debugPrint('Received bid_placed: $data');
      final bid = AuctionBid.fromJson(data);
      final nominationId = bid.nominationId;

      // Update bid list for this nomination
      if (!_nominationBids.containsKey(nominationId)) {
        _nominationBids[nominationId] = [];
      }
      _nominationBids[nominationId]!.add(bid);

      // Update nomination's winning bid
      final nominationIndex = _activeNominations.indexWhere((n) => n.id == nominationId);
      if (nominationIndex != -1) {
        // Create updated nomination with new winning bid
        _activeNominations[nominationIndex] = _activeNominations[nominationIndex].copyWith(
          winningBid: bid.bidAmount,
          winningRosterId: bid.rosterId,
          winningTeamName: bid.teamName,
        );

        // Add to activity feed
        final nomination = _activeNominations[nominationIndex];
        _activityFeed.insert(
          0,
          ActivityItem(
            type: 'bid',
            description: '${bid.teamName} bid \$${bid.bidAmount} on ${nomination.playerName}',
            timestamp: DateTime.now(),
            playerId: nomination.playerId,
            playerName: nomination.playerName,
            rosterId: bid.rosterId,
            teamName: bid.teamName,
            amount: bid.bidAmount,
          ),
        );
      }

      notifyListeners();
    };

    _socketService.onPlayerWon = (data) {
      debugPrint('Received player_won: $data');
      final nominationId = data['nominationId'] as int;
      final playerName = data['playerName'] as String?;
      final teamName = data['teamName'] as String?;
      final amount = data['amount'] as int?;

      // Remove from active nominations
      _activeNominations.removeWhere((n) => n.id == nominationId);
      _nominationBids.remove(nominationId);

      // Add to activity feed
      if (playerName != null && teamName != null) {
        _activityFeed.insert(
          0,
          ActivityItem(
            type: 'won',
            description: '$teamName won $playerName for \$${amount ?? 0}',
            timestamp: DateTime.now(),
            playerName: playerName,
            teamName: teamName,
            amount: amount,
          ),
        );
      }

      notifyListeners();
    };

    _socketService.onNominationExpired = (data) {
      debugPrint('Received nomination_expired: $data');
      final nominationId = data['nominationId'] as int;
      final playerName = data['playerName'] as String?;

      // Remove nomination that expired with no bids
      _activeNominations.removeWhere((n) => n.id == nominationId);
      _nominationBids.remove(nominationId);

      // Add to activity feed
      if (playerName != null) {
        _activityFeed.insert(
          0,
          ActivityItem(
            type: 'expired',
            description: '$playerName nomination expired (no bids)',
            timestamp: DateTime.now(),
            playerName: playerName,
          ),
        );
      }

      notifyListeners();
    };

    _socketService.onBudgetUpdated = (data) {
      debugPrint('Received budget_updated: $data');
      final rosterId = data['roster_id'] as int?;

      // Only update if it's my roster
      if (rosterId != null && rosterId == _myRosterId && data['budget'] != null) {
        _myBudget = RosterBudget.fromJson(data['budget']);
        notifyListeners();
      }
    };

    _socketService.onNominationDeadlineUpdated = (data) {
      debugPrint('Received nomination_deadline_updated: $data');
      final nominationId = data['nominationId'] as int?;
      final deadlineStr = data['deadline'] as String?;

      if (nominationId != null && deadlineStr != null) {
        final deadline = DateTime.parse(deadlineStr);

        // Update nomination's deadline
        final nominationIndex = _activeNominations.indexWhere((n) => n.id == nominationId);
        if (nominationIndex != -1) {
          _activeNominations[nominationIndex] = _activeNominations[nominationIndex].copyWith(
            deadline: deadline,
          );
          notifyListeners();
        }
      }
    };

    _socketService.onTurnChanged = (data) {
      debugPrint('Received turn_changed: $data');
      final currentRosterId = data['currentRosterId'] as int?;

      if (currentRosterId != null && _draft != null) {
        _draft = _draft!.copyWith(currentRosterId: currentRosterId);
        notifyListeners();
      }
    };

    _socketService.onError = (error) {
      _errorMessage = error;
      notifyListeners();
    };

    // Connect and join auction
    _socketService.connect();
    _socketService.joinAuction(draftId: draftId);
  }

  // Load initial auction data
  Future<void> loadAuctionData({
    required String token,
    required int draftId,
    required int myRosterId,
    required int leagueId,
  }) async {
    _status = AuctionStatus.loading;
    _errorMessage = null;
    _myRosterId = myRosterId;
    notifyListeners();

    try {
      // Load all data in parallel
      await Future.wait([
        _loadActiveNominations(token, draftId),
        _loadAvailablePlayers(token, draftId),
        _loadMyBudget(token, draftId, myRosterId),
        loadDraftAndRosters(token, draftId, leagueId),
        _loadActivityFeed(token, draftId),
        _loadAuctionRosters(token, draftId),
      ]);

      _status = AuctionStatus.loaded;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading auction data: ${e.toString()}';
      _status = AuctionStatus.error;
      notifyListeners();
    }
  }

  Future<void> _loadActiveNominations(String token, int draftId) async {
    _activeNominations = await _auctionService.getActiveNominations(
      token: token,
      draftId: draftId,
    );

    // Load bids for each nomination
    for (final nomination in _activeNominations) {
      final bids = await _auctionService.getBidHistory(
        token: token,
        draftId: draftId,
        nominationId: nomination.id,
      );
      _nominationBids[nomination.id] = bids;
    }
  }

  Future<void> _loadAvailablePlayers(String token, int draftId) async {
    _availablePlayers = await _auctionService.getAvailablePlayersForAuction(
      token: token,
      draftId: draftId,
    );
  }


  Future<void> _loadMyBudget(String token, int draftId, int rosterId) async {
    final budgetData = await _auctionService.getRosterBudget(
      token: token,
      draftId: draftId,
      rosterId: rosterId,
    );

    if (budgetData != null) {
      _myBudget = RosterBudget.fromJson(budgetData);
    }
  }

  Future<void> _loadActivityFeed(String token, int draftId) async {
    _activityFeed = await _auctionService.getActivityFeed(
      token: token,
      draftId: draftId,
      limit: 100,
    );
  }

  Future<void> _loadAuctionRosters(String token, int draftId) async {
    _auctionRosters = await _auctionService.getAuctionRosters(
      token: token,
      draftId: draftId,
    );
  }

  // Public method to refresh auction rosters
  Future<void> refreshAuctionRosters(String token, int draftId) async {
    await _loadAuctionRosters(token, draftId);
    notifyListeners();
  }

  // Nominate a player
  Future<bool> nominatePlayer(
    String token,
    int draftId,
    String playerId,
    int rosterId,
  ) async {
    try {
      await _auctionService.nominatePlayer(
        token: token,
        draftId: draftId,
        playerId: playerId,
        rosterId: rosterId,
      );

      // Remove from available players
      _availablePlayers.removeWhere((p) => p.playerId == playerId);

      // Socket will handle adding to active nominations
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Place a bid
  Future<bool> placeBid(
    String token,
    int nominationId,
    int rosterId,
    int maxBid,
    int draftId,
  ) async {
    try {
      await _auctionService.placeBid(
        token: token,
        nominationId: nominationId,
        rosterId: rosterId,
        maxBid: maxBid,
        draftId: draftId,
      );

      // Socket will handle updating bid state
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Filter available players
  Future<void> filterPlayers({
    required String token,
    required int draftId,
    String? position,
    String? team,
    String? search,
  }) async {
    _availablePlayers = await _auctionService.getAvailablePlayersForAuction(
      token: token,
      draftId: draftId,
      position: position,
      team: team,
      search: search,
    );
    notifyListeners();
  }

  // Refresh budget
  Future<void> refreshBudget(String token, int draftId, int rosterId) async {
    await _loadMyBudget(token, draftId, rosterId);
    notifyListeners();
  }

  // Load draft and rosters
  Future<void> loadDraftAndRosters(String token, int draftId, int leagueId) async {
    try {
      final draftResult = await _draftService.getDraft(draftId);
      if (draftResult != null) {
        _draft = draftResult;
      }

      // Load rosters from league details
      final leagueDetails = await _leagueService.getLeagueDetails(leagueId);
      if (leagueDetails != null && leagueDetails['rosters'] != null) {
        _rosters = (leagueDetails['rosters'] as List<dynamic>)
            .map((r) => r as Roster)
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading draft and rosters: $e');
    }
  }

  // Start draft
  Future<bool> startDraft(String token, int draftId) async {
    try {
      final result = await _draftService.startDraft(token: token, draftId: draftId);
      if (result != null) {
        _draft = result;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Pause draft
  Future<bool> pauseDraft(String token, int draftId) async {
    try {
      final result = await _draftService.pauseDraft(token: token, draftId: draftId);
      if (result != null) {
        _draft = result;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Resume draft
  Future<bool> resumeDraft(String token, int draftId) async {
    try {
      final result = await _draftService.resumeDraft(token: token, draftId: draftId);
      if (result != null) {
        _draft = result;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Get current nominator team name
  String? getCurrentNominatorName() {
    if (_draft?.currentRosterId == null) return null;
    try {
      final roster = _rosters.firstWhere(
        (r) => r.id == _draft!.currentRosterId,
      );
      return roster.settings?['team_name'] as String? ?? roster.username;
    } catch (e) {
      return null;
    }
  }

  // Check if it's my turn
  bool get isMyTurn {
    return _draft?.currentRosterId == _myRosterId;
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    _socketService.disconnect();
    _socketService.clearCallbacks();
    super.dispose();
  }
}
