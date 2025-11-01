import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/draft_model.dart';
import '../models/draft_pick_model.dart';
import '../models/draft_order_model.dart';
import '../models/draft_chat_message_model.dart';
import '../models/draft_derby_model.dart';
import '../models/player_model.dart';
import '../services/draft_service.dart';
import '../services/draft_derby_service.dart';
import '../services/socket_service.dart';
import '../utils/debounce.dart';

enum DraftStatus {
  initial,
  loading,
  loaded,
  error,
}

class DraftProvider with ChangeNotifier {
  final DraftService _draftService = DraftService();
  final DraftDerbyService _derbyService = DraftDerbyService();
  final SocketService _socketService = SocketService();
  final _filterDebouncer = Debouncer(delay: Duration(milliseconds: 300));

  DraftStatus _status = DraftStatus.initial;
  Draft? _currentDraft;
  List<DraftOrder> _draftOrder = [];
  List<DraftPick> _draftPicks = [];
  List<Player> _availablePlayers = [];
  List<DraftChatMessage> _chatMessages = [];
  String? _errorMessage;
  String? _authToken; // Store auth token for authenticated API calls

  // Timer for countdown - now calculated from deadline
  Timer? _timer;
  DateTime? _currentPickDeadline;
  DateTime? _serverTime;
  DateTime? _lastSyncTime;

  // Chess timer state - tracks remaining time for each roster
  Map<int, int> _rosterTimeRemaining = {};

  // Derby state
  DraftDerbyWithDetails? _currentDerby;
  bool _derbyLoading = false;
  String? _derbyError;
  DateTime? _derbyTurnDeadline;
  DateTime? _derbyServerTime;
  DateTime? _derbyLastSyncTime;

  // Getters
  DraftStatus get status => _status;
  Draft? get currentDraft => _currentDraft;
  List<DraftOrder> get draftOrder => _draftOrder;
  List<DraftPick> get draftPicks => _draftPicks;
  List<Player> get availablePlayers => _availablePlayers;
  List<DraftChatMessage> get chatMessages => _chatMessages;
  String? get errorMessage => _errorMessage;
  bool get isSocketConnected => _socketService.isConnected;

  // Calculate time remaining based on deadline
  Duration? get timeRemaining {
    if (_currentPickDeadline == null) return null;

    final now = _estimateServerTime();
    final remaining = _currentPickDeadline!.difference(now);

    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Get remaining time for a specific roster (chess timer mode)
  int? getRosterTimeRemaining(int rosterId) => _rosterTimeRemaining[rosterId];

  // Check if chess timer mode is enabled
  bool get isChessTimerMode => _currentDraft?.isChessTimer ?? false;

  // Derby getters
  DraftDerbyWithDetails? get currentDerby => _currentDerby;
  bool get derbyLoading => _derbyLoading;
  String? get derbyError => _derbyError;
  bool get isDerbyActive => _currentDerby?.derby.isInProgress ?? false;
  bool get isDerbyCompleted => _currentDerby?.derby.isCompleted ?? false;
  bool get isDerbyEnabled => _currentDraft?.derbyEnabled ?? false;

  // Calculate derby time remaining
  Duration? get derbyTimeRemaining {
    if (_derbyTurnDeadline == null) return null;

    final now = _estimateDerbyServerTime();
    final remaining = _derbyTurnDeadline!.difference(now);

    return remaining.isNegative ? Duration.zero : remaining;
  }

  DraftProvider() {
    _setupSocketListeners();
  }

  // Estimate current derby server time
  DateTime _estimateDerbyServerTime() {
    if (_derbyServerTime == null || _derbyLastSyncTime == null) {
      return DateTime.now();
    }

    final localElapsed = DateTime.now().difference(_derbyLastSyncTime!);
    return _derbyServerTime!.add(localElapsed);
  }

  // Estimate current server time accounting for client clock drift
  DateTime _estimateServerTime() {
    if (_serverTime == null || _lastSyncTime == null) {
      return DateTime.now();
    }

    // Calculate how much time has passed locally since last sync
    final localElapsed = DateTime.now().difference(_lastSyncTime!);

    // Add that to the last known server time
    return _serverTime!.add(localElapsed);
  }

  // Handle timer update from server
  void _handleTimerUpdate(Map<String, dynamic> data) {
    try {
      _currentPickDeadline = DateTime.parse(data['deadline']);
      _serverTime = DateTime.parse(data['server_time']);
      _lastSyncTime = DateTime.now();

      debugPrint('[TimerSync] Updated deadline: $_currentPickDeadline, Server time: $_serverTime');
      notifyListeners();
    } catch (e) {
      debugPrint('[TimerSync] Error parsing timer update: $e');
    }
  }

  // Setup WebSocket event listeners
  void _setupSocketListeners() {
    _socketService.onPickMade = (data) {
      debugPrint('[DraftProvider] onPickMade received: ${data.keys}');

      // Update draft and picks
      if (data['draft'] != null) {
        _currentDraft = Draft.fromJson(data['draft']);
        debugPrint('[DraftProvider] Updated draft: pick ${_currentDraft?.currentPick}, status ${_currentDraft?.status}');
      }
      if (data['pick'] != null) {
        final pick = DraftPick.fromJson(data['pick']);
        _draftPicks.add(pick);
        print('[DraftProvider] Added pick: ${pick.playerName} (pick.playerId: ${pick.playerId}, type: ${pick.playerId.runtimeType})');

        // Remove picked player from available players
        // pick.playerId should be the database player.id (integer from players table)
        final beforeCount = _availablePlayers.length;

        // Debug: log all available player IDs to see what we're matching against
        print('[DraftProvider] Available player IDs: ${_availablePlayers.map((p) => 'id=${p.id} playerId=${p.playerId}').take(5).join(', ')}...');

        _availablePlayers.removeWhere((player) {
          final matches = player.id == pick.playerId;
          if (matches) {
            print('[DraftProvider] MATCH FOUND: player.id=${player.id} == pick.playerId=${pick.playerId}');
          }
          return matches;
        });

        final afterCount = _availablePlayers.length;
        print('[DraftProvider] Removed player from available list. Before: $beforeCount, After: $afterCount');

        if (beforeCount == afterCount) {
          print('[DraftProvider] WARNING: Player was NOT removed! pick.playerId=${pick.playerId} not found in available list');
        }
      }

      // Update deadline if next_deadline is provided
      if (data['next_deadline'] != null && data['server_time'] != null) {
        _currentPickDeadline = DateTime.parse(data['next_deadline']);
        _serverTime = DateTime.parse(data['server_time']);
        _lastSyncTime = DateTime.now();
      }

      notifyListeners();
    };

    _socketService.onStatusChanged = (data) {
      if (data['draft'] != null) {
        _currentDraft = Draft.fromJson(data['draft']);
        notifyListeners();
      }
    };

    _socketService.onOrderUpdated = (orders) {
      debugPrint('[DraftProvider] onOrderUpdated received ${orders.length} rosters');
      _draftOrder = orders;
      notifyListeners();
    };

    _socketService.onChatMessage = (message) {
      _chatMessages.add(message);
      notifyListeners();
    };

    _socketService.onDraftState = (draft) {
      _currentDraft = draft;
      notifyListeners();
    };

    _socketService.onError = (error) {
      _errorMessage = error;
      _status = DraftStatus.error;
      notifyListeners();
    };

    _socketService.onAutodraftToggled = (data) {
      final rosterId = data['roster_id'] as int;
      final isAutodrafting = data['is_autodrafting'] as bool;

      // Update draft order list with new autodraft status
      _draftOrder = _draftOrder.map((order) {
        if (order.rosterId == rosterId) {
          return order.copyWith(isAutodrafting: isAutodrafting);
        }
        return order;
      }).toList();

      notifyListeners();
    };

    // Timer update event - server broadcasts deadline every 5 seconds
    _socketService.onTimerUpdate = _handleTimerUpdate;

    // Draft started event
    _socketService.onDraftStarted = (data) {
      if (data['draft'] != null) {
        _currentDraft = Draft.fromJson(data['draft']);
      }
      if (data['deadline'] != null && data['server_time'] != null) {
        _currentPickDeadline = DateTime.parse(data['deadline']);
        _serverTime = DateTime.parse(data['server_time']);
        _lastSyncTime = DateTime.now();
      }
      _startTimerUI();
      notifyListeners();
    };

    // Draft paused event
    _socketService.onDraftPaused = (data) {
      if (data['draft'] != null) {
        _currentDraft = Draft.fromJson(data['draft']);
      }
      _currentPickDeadline = null;
      _stopTimer();
      notifyListeners();
    };

    // Draft resumed event
    _socketService.onDraftResumed = (data) {
      if (data['draft'] != null) {
        _currentDraft = Draft.fromJson(data['draft']);
      }
      if (data['deadline'] != null && data['server_time'] != null) {
        _currentPickDeadline = DateTime.parse(data['deadline']);
        _serverTime = DateTime.parse(data['server_time']);
        _lastSyncTime = DateTime.now();
      }
      _startTimerUI();
      notifyListeners();
    };

    // Chess timer update event
    _socketService.onChessTimerUpdate = (data) {
      debugPrint('Chess timer update: $data');
      final rosterId = data['roster_id'] as int;
      final timeRemaining = data['time_remaining_seconds'] as int;

      // Update local chess timer state
      _rosterTimeRemaining[rosterId] = timeRemaining;

      // Update draft order with new time
      _draftOrder = _draftOrder.map((order) {
        if (order.rosterId == rosterId) {
          return order.copyWith(timeRemainingSeconds: timeRemaining);
        }
        return order;
      }).toList();

      notifyListeners();
    };

    // Time adjustment event (commissioner adjusted time)
    _socketService.onTimeAdjusted = (data) {
      debugPrint('Time adjusted: $data');
      final rosterId = data['roster_id'] as int;
      final newTimeRemaining = data['new_time_remaining_seconds'] as int;

      // Update local chess timer state
      _rosterTimeRemaining[rosterId] = newTimeRemaining;

      // Update draft order with new time
      _draftOrder = _draftOrder.map((order) {
        if (order.rosterId == rosterId) {
          return order.copyWith(timeRemainingSeconds: newTimeRemaining);
        }
        return order;
      }).toList();

      notifyListeners();
    };

    // Derby socket listeners
    _socketService.onDerbyUpdate = (data) {
      debugPrint('[DraftProvider] Derby update: $data');
      if (data['derby'] != null) {
        try {
          _currentDerby = DraftDerbyWithDetails.fromJson(data['derby']);
          notifyListeners();
        } catch (e) {
          debugPrint('[DraftProvider] Error parsing derby update: $e');
        }
      }
    };

    _socketService.onDerbySelectionMade = (data) {
      debugPrint('[DraftProvider] Derby selection made: $data');
      // Refresh derby state
      if (_authToken != null && _currentDraft != null) {
        loadDerby(token: _authToken!, draftId: _currentDraft!.id);
      }
    };

    _socketService.onDerbyTurnChanged = (data) {
      debugPrint('[DraftProvider] Derby turn changed: $data');
      if (_authToken != null && _currentDraft != null) {
        loadDerby(token: _authToken!, draftId: _currentDraft!.id);
      }
    };

    _socketService.onDerbyCompleted = (data) {
      debugPrint('[DraftProvider] Derby completed: $data');
      // Refresh derby and draft state
      if (_authToken != null && _currentDraft != null) {
        loadDerby(token: _authToken!, draftId: _currentDraft!.id);
        loadDraftByLeague(_authToken!, _currentDraft!.leagueId);
      }
    };

    _socketService.onDerbyTimerUpdate = (data) {
      if (data['deadline'] != null && data['server_time'] != null) {
        _derbyTurnDeadline = DateTime.parse(data['deadline']);
        _derbyServerTime = DateTime.parse(data['server_time']);
        _derbyLastSyncTime = DateTime.now();
        notifyListeners();
      }
    };

    _socketService.onDerbyTimeout = (data) {
      debugPrint('[DraftProvider] Derby timeout: $data');
      // Refresh derby state to see auto-assigned or skipped result
      if (_authToken != null && _currentDraft != null) {
        loadDerby(token: _authToken!, draftId: _currentDraft!.id);
      }
    };
  }

  // Create a new draft
  Future<bool> createDraft({
    required String token,
    required int leagueId,
    required String draftType,
    bool thirdRoundReversal = false,
    int pickTimeSeconds = 90,
    int rounds = 15,
    String timerMode = 'traditional',
    int? teamTimeBudgetSeconds,
    Map<String, dynamic>? settings,
    // Auction-specific
    int? startingBudget,
    int? minBid,
    int? nominationsPerManager,
    int? nominationTimerHours,
    bool? reserveBudgetPerSlot,
    // Derby-specific
    bool? derbyEnabled,
    int? derbyTimeLimitSeconds,
    String? derbyTimeoutBehavior,
  }) async {
    _status = DraftStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final draft = await _draftService.createDraft(
        token: token,
        leagueId: leagueId,
        draftType: draftType,
        thirdRoundReversal: thirdRoundReversal,
        pickTimeSeconds: pickTimeSeconds,
        rounds: rounds,
        timerMode: timerMode,
        teamTimeBudgetSeconds: teamTimeBudgetSeconds,
        settings: settings,
        // Auction-specific
        startingBudget: startingBudget,
        minBid: minBid,
        nominationsPerManager: nominationsPerManager,
        nominationTimerHours: nominationTimerHours,
        reserveBudgetPerSlot: reserveBudgetPerSlot,
        // Derby-specific
        derbyEnabled: derbyEnabled,
        derbyTimeLimitSeconds: derbyTimeLimitSeconds,
        derbyTimeoutBehavior: derbyTimeoutBehavior,
      );

      if (draft != null) {
        _currentDraft = draft;
        _status = DraftStatus.loaded;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to create draft';
        _status = DraftStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error creating draft: ${e.toString()}';
      _status = DraftStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Load draft by league ID
  Future<void> loadDraftByLeague(String token, int leagueId) async {
    _status = DraftStatus.loading;
    _errorMessage = null;
    _authToken = token; // Store token for use in other methods

    debugPrint('[DraftProvider] loadDraftByLeague started for leagueId=$leagueId, tokenLength=${token.length}');
    notifyListeners();

    try {
      final draft = await _draftService.getDraftByLeague(
        token: token,
        leagueId: leagueId,
      );
      debugPrint('[DraftProvider] getDraftByLeague response: draft=${draft != null ? draft.id : "null"}');

      if (draft != null) {
        _currentDraft = draft;
        // Load related data with token for authentication
        await Future.wait([
          _loadDraftOrder(token, draft.id),
          _loadDraftPicks(token, draft.id),
          _loadAvailablePlayers(token, draft.id),
          _loadChatMessages(token, draft.id),
        ]);
        _initializeChessTimerState();

        // Initialize deadline from draft if in progress
        if (draft.isInProgress && draft.pickDeadline != null) {
          _currentPickDeadline = draft.pickDeadline;
          _serverTime = DateTime.now(); // Initial estimate
          _lastSyncTime = DateTime.now();
          _startTimerUI();
        }

        _status = DraftStatus.loaded;
        debugPrint('[DraftProvider] Draft loaded successfully: id=${draft.id}, status=${draft.status}');
      } else {
        // No draft exists for this league - clear the current draft
        _currentDraft = null;
        _draftOrder = [];
        _draftPicks = [];
        _availablePlayers = [];
        _chatMessages = [];
        _rosterTimeRemaining = {};
        _status = DraftStatus.loaded;
        debugPrint('[DraftProvider] No draft found for league=$leagueId');
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading draft: ${e.toString()}';
      _status = DraftStatus.error;
      debugPrint('[DraftProvider] ERROR loading draft: $e');
      notifyListeners();
    }
  }

  // Load draft order
  Future<void> _loadDraftOrder(String token, int draftId) async {
    _draftOrder = await _draftService.getDraftOrder(token: token, draftId: draftId);
  }

  // Load draft picks
  Future<void> _loadDraftPicks(String token, int draftId) async {
    _draftPicks = await _draftService.getDraftPicks(token: token, draftId: draftId, withDetails: true);
  }

  // Load available players
  Future<void> _loadAvailablePlayers(String token, int draftId) async {
    _availablePlayers = await _draftService.getAvailablePlayers(token: token, draftId: draftId);
  }

  // Load chat messages
  Future<void> _loadChatMessages(String token, int draftId) async {
    _chatMessages = await _draftService.getChatMessages(token: token, draftId: draftId);
  }

  // Set draft order
  Future<bool> setDraftOrder({
    required String token,
    required int draftId,
    bool randomize = false,
    List<Map<String, int>>? order,
  }) async {
    try {
      debugPrint('[DraftProvider] setDraftOrder called: randomize=$randomize, draftId=$draftId');

      final newOrder = await _draftService.setDraftOrder(
        token: token,
        draftId: draftId,
        randomize: randomize,
        order: order,
      );

      if (newOrder.isNotEmpty) {
        _draftOrder = newOrder;
        debugPrint('[DraftProvider] Draft order updated with ${newOrder.length} rosters');
        notifyListeners();
        return true;
      }
      debugPrint('[DraftProvider] setDraftOrder returned empty order');
      return false;
    } catch (e) {
      _errorMessage = 'Error setting draft order: ${e.toString()}';
      debugPrint('[DraftProvider] setDraftOrder error: $e');
      notifyListeners();
      return false;
    }
  }

  // Start draft
  Future<bool> startDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final draft = await _draftService.startDraft(
        token: token,
        draftId: draftId,
      );

      if (draft != null) {
        _currentDraft = draft;
        // Note: Deadline will be set via socket event (draft_started)
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error starting draft: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Pause draft
  Future<bool> pauseDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final draft = await _draftService.pauseDraft(
        token: token,
        draftId: draftId,
      );

      if (draft != null) {
        _currentDraft = draft;
        _currentPickDeadline = null;
        _stopTimer();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error pausing draft: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Resume draft
  Future<bool> resumeDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final draft = await _draftService.resumeDraft(
        token: token,
        draftId: draftId,
      );

      if (draft != null) {
        _currentDraft = draft;
        // Note: Deadline will be set via socket event (draft_resumed)
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error resuming draft: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Reset draft
  Future<bool> resetDraft({
    required String token,
    required int draftId,
  }) async {
    try {
      final draft = await _draftService.resetDraft(
        token: token,
        draftId: draftId,
      );

      if (draft != null) {
        _currentDraft = draft;
        _draftPicks.clear();
        _stopTimer();
        // Reload available players since all players are now available again
        if (_authToken != null) {
          await _loadAvailablePlayers(_authToken!, draftId);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error resetting draft: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Make a draft pick
  Future<bool> makePick({
    required String token,
    required int draftId,
    required int rosterId,
    required int playerId,
  }) async {
    try {
      debugPrint('[DraftProvider] makePick called: playerId=$playerId, rosterId=$rosterId');

      final result = await _draftService.makePick(
        token: token,
        draftId: draftId,
        rosterId: rosterId,
        playerId: playerId,
      );

      if (result != null) {
        debugPrint('[DraftProvider] makePick successful, result keys: ${result.keys}');

        // Don't add the pick here - let the WebSocket handle it
        // The WebSocket pick will have all the extended fields (player_name, etc.)
        // Also don't remove the player here - WebSocket will handle it
        // This prevents double-removal and ensures UI updates happen in sync

        // Update draft state
        _currentDraft = result['draft'];

        // Clear any previous error messages
        _errorMessage = null;

        // Note: WebSocket will trigger notifyListeners() when pick_made event arrives
        // with the full pick data and will remove the player from available list
        notifyListeners();
        return true;
      }
      debugPrint('[DraftProvider] makePick failed: result is null');
      return false;
    } catch (e) {
      _errorMessage = 'Error making pick: ${e.toString()}';
      debugPrint('[DraftProvider] makePick error: $e');
      notifyListeners();
      return false;
    }
  }

  // Filter available players
  Future<void> filterPlayers({
    required String token,
    String? position,
    String? team,
    String? search,
  }) async {
    if (_currentDraft == null) return;

    _filterDebouncer(() async {
      _availablePlayers = await _draftService.getAvailablePlayers(
        token: token,
        draftId: _currentDraft!.id,
        position: position,
        team: team,
        search: search,
      );
      notifyListeners();
    });
  }

  // Send chat message
  Future<void> sendChatMessage({
    required String token,
    required int draftId,
    required int userId,
    required String message,
  }) async {
    // Send via socket for real-time
    _socketService.sendChatMessage(
      draftId: draftId,
      userId: userId,
      username: '', // Will be filled by backend
      message: message,
    );

    // Also send via HTTP as backup
    await _draftService.sendChatMessage(
      token: token,
      draftId: draftId,
      userId: userId,
      message: message,
    );
  }

  // Join draft room (WebSocket)
  Future<void> joinDraftRoom({
    required int draftId,
    required int userId,
    required String username,
  }) async {
    // Initialize socket with stored auth token before connecting
    if (_authToken != null) {
      await _socketService.initializeWithToken(_authToken!);
      debugPrint('[DraftProvider] Socket initialized with token for WebSocket connection');
    } else {
      debugPrint('[DraftProvider] WARNING: No auth token available for socket connection!');
    }

    await _socketService.connect();
    _socketService.joinDraft(
      draftId: draftId,
      userId: userId,
      username: username,
    );
  }

  // Leave draft room (WebSocket)
  void leaveDraftRoom({
    required int draftId,
    required int userId,
    required String username,
  }) {
    _socketService.leaveDraft(
      draftId: draftId,
      userId: userId,
      username: username,
    );
  }

  // Toggle autodraft (WebSocket)
  void toggleAutodraft({
    required int draftId,
    required int rosterId,
    required bool isAutodrafting,
    required String username,
  }) {
    _socketService.toggleAutodraft(
      draftId: draftId,
      rosterId: rosterId,
      isAutodrafting: isAutodrafting,
      username: username,
    );
  }

  // Timer management - UI timer that updates every second
  void _startTimerUI() {
    _stopTimer();

    if (_currentPickDeadline == null) {
      debugPrint('[Timer] No deadline set, not starting UI timer');
      return;
    }

    debugPrint('[Timer] Starting UI timer with deadline: $_currentPickDeadline');

    // Update UI every second (calculation uses deadline)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Recalculate time remaining on each tick
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // Cleanup
  @override
  void dispose() {
    _stopTimer();
    _filterDebouncer.dispose();
    _socketService.disconnect();
    _socketService.clearCallbacks();
    super.dispose();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh draft state
  Future<void> refreshDraft() async {
    if (_currentDraft == null || _authToken == null) return;

    final draft = await _draftService.getDraft(token: _authToken!, draftId: _currentDraft!.id);
    if (draft != null) {
      _currentDraft = draft;
      await Future.wait([
        _loadDraftOrder(_authToken!, _currentDraft!.id),
        _loadDraftPicks(_authToken!, _currentDraft!.id),
        _loadAvailablePlayers(_authToken!, _currentDraft!.id),
      ]);
      _initializeChessTimerState();

      // Initialize deadline from draft if in progress
      if (draft.isInProgress && draft.pickDeadline != null) {
        _currentPickDeadline = draft.pickDeadline;
        _serverTime = DateTime.now(); // Initial estimate
        _lastSyncTime = DateTime.now();
        _startTimerUI();
      }

      notifyListeners();
    }
  }

  // Initialize chess timer state from draft order
  void _initializeChessTimerState() {
    if (_currentDraft?.isChessTimer == true) {
      _rosterTimeRemaining.clear();
      for (final order in _draftOrder) {
        if (order.timeRemainingSeconds != null) {
          _rosterTimeRemaining[order.rosterId] = order.timeRemainingSeconds!;
        }
      }
      debugPrint('Initialized chess timer state: $_rosterTimeRemaining');
    }
  }

  // Adjust roster time (commissioner only)
  Future<bool> adjustRosterTime({
    required String token,
    required int draftId,
    required int rosterId,
    required int adjustmentSeconds,
  }) async {
    try {
      final success = await _draftService.adjustRosterTime(
        token: token,
        draftId: draftId,
        rosterId: rosterId,
        adjustmentSeconds: adjustmentSeconds,
      );

      if (success) {
        // Socket event will handle updating the state
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error adjusting roster time: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Derby Methods

  /// Load derby state for a draft
  Future<void> loadDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      _derbyLoading = true;
      _derbyError = null;
      notifyListeners();

      final derby = await _derbyService.getDerby(
        token: token,
        draftId: draftId,
      );

      _currentDerby = derby;
      _derbyLoading = false;
      notifyListeners();
    } catch (e) {
      _derbyError = 'Error loading derby: ${e.toString()}';
      _derbyLoading = false;
      notifyListeners();
    }
  }

  /// Create a new derby (commissioner only)
  Future<bool> createDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      _derbyLoading = true;
      _derbyError = null;
      notifyListeners();

      final derby = await _derbyService.createDerby(
        token: token,
        draftId: draftId,
      );

      if (derby != null) {
        // Reload full derby details
        await loadDerby(token: token, draftId: draftId);
        return true;
      }

      _derbyError = 'Failed to create derby';
      _derbyLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _derbyError = 'Error creating derby: ${e.toString()}';
      _derbyLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Start the derby (commissioner only)
  Future<bool> startDerby({
    required String token,
    required int draftId,
  }) async {
    try {
      _derbyLoading = true;
      _derbyError = null;
      notifyListeners();

      final derby = await _derbyService.startDerby(
        token: token,
        draftId: draftId,
      );

      if (derby != null) {
        // Reload full derby details
        await loadDerby(token: token, draftId: draftId);
        return true;
      }

      _derbyError = 'Failed to start derby';
      _derbyLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _derbyError = 'Error starting derby: ${e.toString()}';
      _derbyLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Make a derby selection
  Future<bool> makeDerbySelection({
    required String token,
    required int draftId,
    required int rosterId,
    required int draftPosition,
  }) async {
    try {
      _derbyLoading = true;
      _derbyError = null;
      notifyListeners();

      final result = await _derbyService.makeSelection(
        token: token,
        draftId: draftId,
        rosterId: rosterId,
        draftPosition: draftPosition,
      );

      if (result != null) {
        _currentDerby = result['derby'] as DraftDerbyWithDetails;
        _derbyLoading = false;
        notifyListeners();
        return true;
      }

      _derbyError = 'Failed to make selection';
      _derbyLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _derbyError = e.toString().replaceAll('Exception: ', '');
      _derbyLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Skip current turn (for timeout or commissioner action)
  Future<bool> skipDerbyTurn({
    required String token,
    required int draftId,
  }) async {
    try {
      _derbyLoading = true;
      _derbyError = null;
      notifyListeners();

      final derby = await _derbyService.skipTurn(
        token: token,
        draftId: draftId,
      );

      if (derby != null) {
        _currentDerby = derby;
        _derbyLoading = false;
        notifyListeners();
        return true;
      }

      _derbyError = 'Failed to skip turn';
      _derbyLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _derbyError = 'Error skipping turn: ${e.toString()}';
      _derbyLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear derby error
  void clearDerbyError() {
    _derbyError = null;
    notifyListeners();
  }
}
