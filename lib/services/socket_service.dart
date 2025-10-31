import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../models/draft_model.dart';
import '../models/draft_order_model.dart';
import '../models/draft_chat_message_model.dart';
import '../models/league_chat_message_model.dart';

class SocketService {
  IO.Socket? _socket;
  int? _currentDraftId;
  int? _currentLeagueId;
  String? _authToken; // Store token for socket authentication

  // Draft event callbacks
  Function(Map<String, dynamic>)? onPickMade;
  Function(Map<String, dynamic>)? onStatusChanged;
  Function(List<DraftOrder>)? onOrderUpdated;
  Function(DraftChatMessage)? onChatMessage;
  Function(Map<String, dynamic>)? onUserJoined;
  Function(Map<String, dynamic>)? onUserLeft;
  Function(Map<String, dynamic>)? onTimerTick;
  Function(Draft)? onDraftState;
  Function(Map<String, dynamic>)? onAutodraftToggled;
  Function(Map<String, dynamic>)? onChessTimerUpdate;
  Function(Map<String, dynamic>)? onTimeAdjusted;
  Function(Map<String, dynamic>)? onTimerUpdate;
  Function(Map<String, dynamic>)? onDraftStarted;
  Function(Map<String, dynamic>)? onDraftPaused;
  Function(Map<String, dynamic>)? onDraftResumed;
  Function(String)? onError;

  // League event callbacks
  Function(LeagueChatMessage)? onLeagueChatMessage;
  Function(Map<String, dynamic>)? onUserJoinedLeague;
  Function(Map<String, dynamic>)? onUserLeftLeague;

  // Matchup event callbacks
  Function(Map<String, dynamic>)? onMatchupScoresUpdated;

  // Trade event callbacks
  Function(Map<String, dynamic>)? onTradeProposed;
  Function(Map<String, dynamic>)? onTradeProcessed;
  Function(Map<String, dynamic>)? onTradeRejected;
  Function(Map<String, dynamic>)? onTradeCancelled;

  // Auction event callbacks
  Function(dynamic)? onActiveNominations;
  Function(dynamic)? onPlayerNominated;
  Function(dynamic)? onBidPlaced;
  Function(Map<String, dynamic>)? onPlayerWon;
  Function(Map<String, dynamic>)? onNominationExpired;
  Function(Map<String, dynamic>)? onBudgetUpdated;
  Function(Map<String, dynamic>)? onNominationDeadlineUpdated;
  Function(Map<String, dynamic>)? onTurnChanged;

  bool get isConnected => _socket?.connected ?? false;

  // Initialize socket with authentication token
  void initializeWithToken(String token) {
    _authToken = token;
    debugPrint('[SocketService] Initialized with token (length=${token.length})');
  }

  // Connect to the WebSocket server
  void connect() {
    if (_socket?.connected == true) {
      debugPrint('Socket already connected');
      return;
    }

    if (_authToken == null) {
      debugPrint('[SocketService] ERROR: Cannot connect - no token set. Call initializeWithToken first!');
      onError?.call('No authentication token provided');
      return;
    }

    try {
      debugPrint('[SocketService] Connecting with token...');
      _socket = IO.io(
        ApiConfig.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': _authToken})
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        debugPrint('Socket connected');
      });

      _socket!.onDisconnect((_) {
        debugPrint('Socket disconnected');
      });

      _socket!.onError((error) {
        debugPrint('Socket error: $error');
        onError?.call(error.toString());
      });

      // Listen for draft events
      _setupEventListeners();
    } catch (e) {
      debugPrint('Socket connection error: $e');
      onError?.call(e.toString());
    }
  }

  // Setup event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // User joined draft
    _socket!.on('user_joined', (data) {
      debugPrint('User joined: $data');
      onUserJoined?.call(data);
    });

    // User left draft
    _socket!.on('user_left', (data) {
      debugPrint('User left: $data');
      onUserLeft?.call(data);
    });

    // Pick made
    _socket!.on('pick_made', (data) {
      debugPrint('Pick made: $data');
      onPickMade?.call(data);
    });

    // Draft status changed
    _socket!.on('status_changed', (data) {
      debugPrint('Status changed: $data');
      onStatusChanged?.call(data);
    });

    // Draft order updated
    _socket!.on('order_updated', (data) {
      debugPrint('Order updated: $data');
      if (data['draft_order'] != null) {
        final orders = (data['draft_order'] as List)
            .map((json) => DraftOrder.fromJson(json))
            .toList();
        onOrderUpdated?.call(orders);
      }
    });

    // Chat message received
    _socket!.on('chat_message', (data) {
      debugPrint('Chat message: $data');
      try {
        final message = DraftChatMessage.fromJson(data);
        onChatMessage?.call(message);
      } catch (e) {
        debugPrint('Error parsing chat message: $e');
      }
    });

    // Timer tick
    _socket!.on('timer_tick', (data) {
      onTimerTick?.call(data);
    });

    // Draft state response
    _socket!.on('draft_state', (data) {
      debugPrint('Draft state: $data');
      if (data['draft'] != null) {
        try {
          final draft = Draft.fromJson(data['draft']);
          onDraftState?.call(draft);
        } catch (e) {
          debugPrint('Error parsing draft state: $e');
        }
      }
    });

    // Autodraft toggled
    _socket!.on('autodraft_toggled', (data) {
      debugPrint('Autodraft toggled: $data');
      onAutodraftToggled?.call(data);
    });

    // Timer update (server broadcasts deadline every 5 seconds)
    _socket!.on('timer_update', (data) {
      debugPrint('Timer update: $data');
      onTimerUpdate?.call(data);
    });

    // Draft started
    _socket!.on('draft_started', (data) {
      debugPrint('Draft started: $data');
      onDraftStarted?.call(data);
    });

    // Draft paused
    _socket!.on('draft_paused', (data) {
      debugPrint('Draft paused: $data');
      onDraftPaused?.call(data);
    });

    // Draft resumed
    _socket!.on('draft_resumed', (data) {
      debugPrint('Draft resumed: $data');
      onDraftResumed?.call(data);
    });

    // Chess timer update
    _socket!.on('chess_timer_update', (data) {
      debugPrint('Chess timer update: $data');
      onChessTimerUpdate?.call(data);
    });

    // Time adjusted (commissioner adjustment)
    _socket!.on('time_adjusted', (data) {
      debugPrint('Time adjusted: $data');
      onTimeAdjusted?.call(data);
    });

    // Joined draft confirmation
    _socket!.on('joined_draft', (data) {
      debugPrint('Joined draft: $data');
    });

    // Error handling
    _socket!.on('error', (data) {
      debugPrint('Server error: $data');
      onError?.call(data['message'] ?? 'Unknown error');
    });

    // Auto-pick made
    _socket!.on('auto_pick_made', (data) {
      debugPrint('Auto-pick made: $data');
    });

    // League chat message
    _socket!.on('league_chat_message', (data) {
      debugPrint('League chat message received: $data');
      try {
        final message = LeagueChatMessage.fromJson(data);
        onLeagueChatMessage?.call(message);
      } catch (e) {
        debugPrint('Error parsing league chat message: $e');
      }
    });

    // User joined league
    _socket!.on('user_joined_league', (data) {
      debugPrint('User joined league: $data');
      onUserJoinedLeague?.call(data);
    });

    // User left league
    _socket!.on('user_left_league', (data) {
      debugPrint('User left league: $data');
      onUserLeftLeague?.call(data);
    });

    // Joined league confirmation
    _socket!.on('joined_league', (data) {
      debugPrint('Joined league: $data');
    });

    // Matchup scores updated (live scores)
    _socket!.on('matchup_scores_updated', (data) {
      debugPrint('Matchup scores updated: ${data['league_id']} week ${data['week']}');
      onMatchupScoresUpdated?.call(data);
    });

    // Joined matchup room confirmation
    _socket!.on('joined_matchup_room', (data) {
      debugPrint('Joined matchup room: $data');
    });

    // Trade proposed
    _socket!.on('trade_proposed', (data) {
      debugPrint('Trade proposed: $data');
      onTradeProposed?.call(data);
    });

    // Trade processed (accepted)
    _socket!.on('trade_processed', (data) {
      debugPrint('Trade processed: $data');
      onTradeProcessed?.call(data);
    });

    // Trade rejected
    _socket!.on('trade_rejected', (data) {
      debugPrint('Trade rejected: $data');
      onTradeRejected?.call(data);
    });

    // Trade cancelled
    _socket!.on('trade_cancelled', (data) {
      debugPrint('Trade cancelled: $data');
      onTradeCancelled?.call(data);
    });

    // Auction events
    _socket!.on('active_nominations', (data) {
      debugPrint('Active nominations: $data');
      onActiveNominations?.call(data);
    });

    _socket!.on('player_nominated', (data) {
      debugPrint('Player nominated: $data');
      onPlayerNominated?.call(data);
    });

    _socket!.on('bid_placed', (data) {
      debugPrint('Bid placed: $data');
      onBidPlaced?.call(data);
    });

    _socket!.on('player_won', (data) {
      debugPrint('Player won: $data');
      onPlayerWon?.call(data);
    });

    _socket!.on('nomination_expired', (data) {
      debugPrint('Nomination expired: $data');
      onNominationExpired?.call(data);
    });

    _socket!.on('budget_updated', (data) {
      debugPrint('Budget updated: $data');
      onBudgetUpdated?.call(data);
    });

    _socket!.on('nomination_deadline_updated', (data) {
      debugPrint('Nomination deadline updated: $data');
      onNominationDeadlineUpdated?.call(data);
    });

    _socket!.on('turn_changed', (data) {
      debugPrint('Turn changed: $data');
      onTurnChanged?.call(data);
    });
  }

  // Join a draft room
  void joinDraft({
    required int draftId,
    required int userId,
    required String username,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Socket not connected, connecting now...');
      connect();

      // Wait for connection before joining
      _socket!.onConnect((_) {
        _emitJoinDraft(draftId, userId, username);
      });
    } else {
      _emitJoinDraft(draftId, userId, username);
    }
  }

  void _emitJoinDraft(int draftId, int userId, String username) {
    _currentDraftId = draftId;
    _socket!.emit('join_draft', {
      'draft_id': draftId,
      'user_id': userId,
      'username': username,
    });
    debugPrint('Emitted join_draft for draft $draftId');
  }

  // Leave a draft room
  void leaveDraft({
    required int draftId,
    required int userId,
    required String username,
  }) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit('leave_draft', {
      'draft_id': draftId,
      'user_id': userId,
      'username': username,
    });
    _currentDraftId = null;
    debugPrint('Left draft $draftId');
  }

  // Send chat message
  void sendChatMessage({
    required int draftId,
    required int userId,
    required String username,
    required String message,
  }) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit('send_chat_message', {
      'draft_id': draftId,
      'user_id': userId,
      'username': username,
      'message': message,
    });
  }

  // Request current draft state
  void requestDraftState(int draftId) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit('request_draft_state', {
      'draft_id': draftId,
    });
  }

  // Join a league room
  void joinLeague({
    required int leagueId,
    required int userId,
    required String username,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Socket not connected, connecting now...');
      connect();

      // Wait for connection before joining
      _socket!.onConnect((_) {
        _emitJoinLeague(leagueId, userId, username);
      });
    } else {
      _emitJoinLeague(leagueId, userId, username);
    }
  }

  void _emitJoinLeague(int leagueId, int userId, String username) {
    _currentLeagueId = leagueId;
    _socket!.emit('join_league', {
      'league_id': leagueId,
      'user_id': userId,
      'username': username,
    });
    debugPrint('Emitted join_league for league $leagueId');
  }

  // Leave a league room
  void leaveLeague({
    required int leagueId,
    required int userId,
    required String username,
  }) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit('leave_league', {
      'league_id': leagueId,
      'user_id': userId,
      'username': username,
    });
    _currentLeagueId = null;
    debugPrint('Left league $leagueId');
  }

  // Send league chat message
  void sendLeagueChatMessage({
    required int leagueId,
    required int userId,
    required String username,
    required String message,
  }) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit('send_league_chat_message', {
      'league_id': leagueId,
      'user_id': userId,
      'username': username,
      'message': message,
    });
  }

  // Toggle autodraft
  void toggleAutodraft({
    required int draftId,
    required int rosterId,
    required bool isAutodrafting,
    required String username,
  }) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit('toggle_autodraft', {
      'draft_id': draftId,
      'roster_id': rosterId,
      'is_autodrafting': isAutodrafting,
      'username': username,
    });
  }

  // Join a league's matchup room for live scores
  void joinLeagueMatchups({
    required int leagueId,
    required int week,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Socket not connected, connecting now...');
      connect();

      // Wait for connection before joining
      _socket!.onConnect((_) {
        _emitJoinLeagueMatchups(leagueId, week);
      });
    } else {
      _emitJoinLeagueMatchups(leagueId, week);
    }
  }

  void _emitJoinLeagueMatchups(int leagueId, int week) {
    _socket!.emit('join_league_matchups', {
      'league_id': leagueId,
      'week': week,
    });
    debugPrint('Joined matchup room for league $leagueId week $week');
  }

  // Leave a league's matchup room
  void leaveLeagueMatchups({
    required int leagueId,
    required int week,
  }) {
    if (_socket == null || !_socket!.connected) return;

    _socket!.emit('leave_league_matchups', {
      'league_id': leagueId,
      'week': week,
    });
    debugPrint('Left matchup room for league $leagueId week $week');
  }

  // Disconnect from WebSocket
  void disconnect() {
    if (_socket == null) return;

    if (_currentDraftId != null) {
      // Leave current draft before disconnecting
      _socket!.emit('leave_draft', {
        'draft_id': _currentDraftId,
      });
    }

    if (_currentLeagueId != null) {
      // Leave current league before disconnecting
      _socket!.emit('leave_league', {
        'league_id': _currentLeagueId,
      });
    }

    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;
    _currentDraftId = null;
    _currentLeagueId = null;
    debugPrint('Socket disconnected and disposed');
  }

  // Join an auction room (slow auctions)
  void joinAuction({required int draftId, int? rosterId}) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Socket not connected, connecting now...');
      connect();

      // Wait for connection before joining
      _socket!.onConnect((_) {
        _emitJoinAuction(draftId, rosterId: rosterId);
      });
    } else {
      _emitJoinAuction(draftId, rosterId: rosterId);
    }
  }

  void _emitJoinAuction(int draftId, {int? rosterId}) {
    _socket!.emit('join_auction', {
      'draftId': draftId,
      if (rosterId != null) 'rosterId': rosterId,
    });
    debugPrint('Emitted join_auction for draft $draftId (roster: $rosterId)');
  }

  // Clear all callbacks
  void clearCallbacks() {
    onPickMade = null;
    onStatusChanged = null;
    onOrderUpdated = null;
    onChatMessage = null;
    onUserJoined = null;
    onUserLeft = null;
    onTimerTick = null;
    onDraftState = null;
    onAutodraftToggled = null;
    onChessTimerUpdate = null;
    onTimeAdjusted = null;
    onError = null;
    onLeagueChatMessage = null;
    onUserJoinedLeague = null;
    onUserLeftLeague = null;
    onMatchupScoresUpdated = null;
    onTradeProposed = null;
    onTradeProcessed = null;
    onTradeRejected = null;
    onTradeCancelled = null;
    onActiveNominations = null;
    onPlayerNominated = null;
    onBidPlaced = null;
    onPlayerWon = null;
    onNominationExpired = null;
    onBudgetUpdated = null;
    onNominationDeadlineUpdated = null;
    onTurnChanged = null;
  }
}
