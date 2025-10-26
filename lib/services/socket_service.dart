import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../models/draft_model.dart';
import '../models/draft_pick_model.dart';
import '../models/draft_order_model.dart';
import '../models/draft_chat_message_model.dart';
import '../models/league_chat_message_model.dart';

class SocketService {
  IO.Socket? _socket;
  int? _currentDraftId;
  int? _currentLeagueId;

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
  Function(String)? onError;

  // League event callbacks
  Function(LeagueChatMessage)? onLeagueChatMessage;
  Function(Map<String, dynamic>)? onUserJoinedLeague;
  Function(Map<String, dynamic>)? onUserLeftLeague;

  bool get isConnected => _socket?.connected ?? false;

  // Connect to the WebSocket server
  void connect() {
    if (_socket?.connected == true) {
      print('Socket already connected');
      return;
    }

    try {
      _socket = IO.io(
        ApiConfig.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        print('Socket connected');
      });

      _socket!.onDisconnect((_) {
        print('Socket disconnected');
      });

      _socket!.onError((error) {
        print('Socket error: $error');
        onError?.call(error.toString());
      });

      // Listen for draft events
      _setupEventListeners();
    } catch (e) {
      print('Socket connection error: $e');
      onError?.call(e.toString());
    }
  }

  // Setup event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // User joined draft
    _socket!.on('user_joined', (data) {
      print('User joined: $data');
      onUserJoined?.call(data);
    });

    // User left draft
    _socket!.on('user_left', (data) {
      print('User left: $data');
      onUserLeft?.call(data);
    });

    // Pick made
    _socket!.on('pick_made', (data) {
      print('Pick made: $data');
      onPickMade?.call(data);
    });

    // Draft status changed
    _socket!.on('status_changed', (data) {
      print('Status changed: $data');
      onStatusChanged?.call(data);
    });

    // Draft order updated
    _socket!.on('order_updated', (data) {
      print('Order updated: $data');
      if (data['draft_order'] != null) {
        final orders = (data['draft_order'] as List)
            .map((json) => DraftOrder.fromJson(json))
            .toList();
        onOrderUpdated?.call(orders);
      }
    });

    // Chat message received
    _socket!.on('chat_message', (data) {
      print('Chat message: $data');
      try {
        final message = DraftChatMessage.fromJson(data);
        onChatMessage?.call(message);
      } catch (e) {
        print('Error parsing chat message: $e');
      }
    });

    // Timer tick
    _socket!.on('timer_tick', (data) {
      onTimerTick?.call(data);
    });

    // Draft state response
    _socket!.on('draft_state', (data) {
      print('Draft state: $data');
      if (data['draft'] != null) {
        try {
          final draft = Draft.fromJson(data['draft']);
          onDraftState?.call(draft);
        } catch (e) {
          print('Error parsing draft state: $e');
        }
      }
    });

    // Autodraft toggled
    _socket!.on('autodraft_toggled', (data) {
      print('Autodraft toggled: $data');
      onAutodraftToggled?.call(data);
    });

    // Joined draft confirmation
    _socket!.on('joined_draft', (data) {
      print('Joined draft: $data');
    });

    // Error handling
    _socket!.on('error', (data) {
      print('Server error: $data');
      onError?.call(data['message'] ?? 'Unknown error');
    });

    // Auto-pick made
    _socket!.on('auto_pick_made', (data) {
      print('Auto-pick made: $data');
    });

    // League chat message
    _socket!.on('league_chat_message', (data) {
      print('League chat message received: $data');
      try {
        final message = LeagueChatMessage.fromJson(data);
        onLeagueChatMessage?.call(message);
      } catch (e) {
        print('Error parsing league chat message: $e');
      }
    });

    // User joined league
    _socket!.on('user_joined_league', (data) {
      print('User joined league: $data');
      onUserJoinedLeague?.call(data);
    });

    // User left league
    _socket!.on('user_left_league', (data) {
      print('User left league: $data');
      onUserLeftLeague?.call(data);
    });

    // Joined league confirmation
    _socket!.on('joined_league', (data) {
      print('Joined league: $data');
    });
  }

  // Join a draft room
  void joinDraft({
    required int draftId,
    required int userId,
    required String username,
  }) {
    if (_socket == null || !_socket!.connected) {
      print('Socket not connected, connecting now...');
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
    print('Emitted join_draft for draft $draftId');
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
    print('Left draft $draftId');
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
      print('Socket not connected, connecting now...');
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
    print('Emitted join_league for league $leagueId');
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
    print('Left league $leagueId');
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
    print('Socket disconnected and disposed');
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
    onError = null;
    onLeagueChatMessage = null;
    onUserJoinedLeague = null;
    onUserLeftLeague = null;
  }
}
