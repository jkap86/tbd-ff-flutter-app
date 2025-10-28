import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/draft_model.dart';
import '../models/draft_pick_model.dart';
import '../models/draft_order_model.dart';
import '../models/draft_chat_message_model.dart';
import '../models/player_model.dart';
import '../services/draft_service.dart';
import '../services/socket_service.dart';

enum DraftStatus {
  initial,
  loading,
  loaded,
  error,
}

class DraftProvider with ChangeNotifier {
  final DraftService _draftService = DraftService();
  final SocketService _socketService = SocketService();

  DraftStatus _status = DraftStatus.initial;
  Draft? _currentDraft;
  List<DraftOrder> _draftOrder = [];
  List<DraftPick> _draftPicks = [];
  List<Player> _availablePlayers = [];
  List<DraftChatMessage> _chatMessages = [];
  String? _errorMessage;

  // Timer for countdown
  Timer? _timer;
  Duration? _timeRemaining;

  // Getters
  DraftStatus get status => _status;
  Draft? get currentDraft => _currentDraft;
  List<DraftOrder> get draftOrder => _draftOrder;
  List<DraftPick> get draftPicks => _draftPicks;
  List<Player> get availablePlayers => _availablePlayers;
  List<DraftChatMessage> get chatMessages => _chatMessages;
  String? get errorMessage => _errorMessage;
  Duration? get timeRemaining => _timeRemaining;
  bool get isSocketConnected => _socketService.isConnected;

  DraftProvider() {
    _setupSocketListeners();
  }

  // Setup WebSocket event listeners
  void _setupSocketListeners() {
    _socketService.onPickMade = (data) {
      // Update draft and picks
      if (data['draft'] != null) {
        _currentDraft = Draft.fromJson(data['draft']);
      }
      if (data['pick'] != null) {
        final pick = DraftPick.fromJson(data['pick']);
        _draftPicks.add(pick);
        // Remove picked player from available players
        _availablePlayers
            .removeWhere((player) => player.id == pick.playerId);
      }
      _resetTimer();
      notifyListeners();
    };

    _socketService.onStatusChanged = (data) {
      if (data['draft'] != null) {
        _currentDraft = Draft.fromJson(data['draft']);
        notifyListeners();
      }
    };

    _socketService.onOrderUpdated = (orders) {
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
  }

  // Create a new draft
  Future<bool> createDraft({
    required String token,
    required int leagueId,
    required String draftType,
    bool thirdRoundReversal = false,
    int pickTimeSeconds = 90,
    int rounds = 15,
    Map<String, dynamic>? settings,
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
        settings: settings,
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
  Future<void> loadDraftByLeague(int leagueId) async {
    _status = DraftStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final draft = await _draftService.getDraftByLeague(leagueId);
      if (draft != null) {
        _currentDraft = draft;
        // Load related data
        await Future.wait([
          _loadDraftOrder(draft.id),
          _loadDraftPicks(draft.id),
          _loadAvailablePlayers(draft.id),
          _loadChatMessages(draft.id),
        ]);
        _resetTimer();
        _status = DraftStatus.loaded;
      } else {
        // No draft exists for this league - clear the current draft
        _currentDraft = null;
        _draftOrder = [];
        _draftPicks = [];
        _availablePlayers = [];
        _chatMessages = [];
        _status = DraftStatus.loaded;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading draft: ${e.toString()}';
      _status = DraftStatus.error;
      notifyListeners();
    }
  }

  // Load draft order
  Future<void> _loadDraftOrder(int draftId) async {
    _draftOrder = await _draftService.getDraftOrder(draftId);
  }

  // Load draft picks
  Future<void> _loadDraftPicks(int draftId) async {
    _draftPicks = await _draftService.getDraftPicks(draftId, withDetails: true);
  }

  // Load available players
  Future<void> _loadAvailablePlayers(int draftId) async {
    _availablePlayers = await _draftService.getAvailablePlayers(draftId);
  }

  // Load chat messages
  Future<void> _loadChatMessages(int draftId) async {
    _chatMessages = await _draftService.getChatMessages(draftId);
  }

  // Set draft order
  Future<bool> setDraftOrder({
    required String token,
    required int draftId,
    bool randomize = false,
    List<Map<String, int>>? order,
  }) async {
    try {
      final newOrder = await _draftService.setDraftOrder(
        token: token,
        draftId: draftId,
        randomize: randomize,
        order: order,
      );

      if (newOrder.isNotEmpty) {
        _draftOrder = newOrder;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error setting draft order: ${e.toString()}';
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
        _resetTimer();
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
        _resetTimer();
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
        await _loadAvailablePlayers(draftId);
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
      final result = await _draftService.makePick(
        token: token,
        draftId: draftId,
        rosterId: rosterId,
        playerId: playerId,
      );

      if (result != null) {
        // Don't add the pick here - let the WebSocket handle it
        // The WebSocket pick will have all the extended fields (player_name, etc.)
        // _draftPicks.add(result['pick']);

        // Update draft state
        _currentDraft = result['draft'];

        // Remove player from available list
        _availablePlayers.removeWhere((player) => player.id == playerId);

        // Note: WebSocket will trigger notifyListeners() when pick_made event arrives
        // But we call it here too to update UI immediately with draft state
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Error making pick: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Filter available players
  Future<void> filterPlayers({
    String? position,
    String? team,
    String? search,
  }) async {
    if (_currentDraft == null) return;

    _availablePlayers = await _draftService.getAvailablePlayers(
      _currentDraft!.id,
      position: position,
      team: team,
      search: search,
    );
    notifyListeners();
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
  void joinDraftRoom({
    required int draftId,
    required int userId,
    required String username,
  }) {
    _socketService.connect();
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

  // Timer management
  void _resetTimer() {
    _stopTimer();

    if (_currentDraft != null &&
        _currentDraft!.isInProgress &&
        _currentDraft!.pickDeadline != null) {
      debugPrint('[Timer] Starting timer. Draft status: ${_currentDraft!.status}, Pick deadline: ${_currentDraft!.pickDeadline}');

      // Set initial time remaining
      _timeRemaining = _currentDraft!.timeRemaining ?? Duration.zero;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final remaining = _currentDraft!.timeRemaining;
        if (remaining != null && remaining.inSeconds > 0) {
          _timeRemaining = remaining;
          notifyListeners();
        } else {
          _timeRemaining = Duration.zero;
          _stopTimer();
          notifyListeners();
        }
      });
    } else {
      debugPrint('[Timer] NOT starting timer. Draft: ${_currentDraft != null}, InProgress: ${_currentDraft?.isInProgress}, Deadline: ${_currentDraft?.pickDeadline}');
      _timeRemaining = Duration.zero;
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _timeRemaining = null;
  }

  // Cleanup
  @override
  void dispose() {
    _stopTimer();
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
    if (_currentDraft == null) return;

    final draft = await _draftService.getDraft(_currentDraft!.id);
    if (draft != null) {
      _currentDraft = draft;
      await Future.wait([
        _loadDraftPicks(_currentDraft!.id),
        _loadAvailablePlayers(_currentDraft!.id),
      ]);
      _resetTimer();
      notifyListeners();
    }
  }
}
