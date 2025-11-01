import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/league_chat_message_model.dart';
import '../services/socket_service.dart';
import '../services/league_chat_service.dart';
import '../utils/burst_throttle.dart';

class LeagueChatWidget extends StatefulWidget {
  final int leagueId;

  const LeagueChatWidget({
    super.key,
    required this.leagueId,
  });

  @override
  State<LeagueChatWidget> createState() => _LeagueChatWidgetState();
}

class _LeagueChatWidgetState extends State<LeagueChatWidget> {
  final LeagueChatService _chatService = LeagueChatService();
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Allow burst of 3 messages in 3 seconds for more natural chat flow
  final _sendThrottler = BurstThrottler(maxActions: 3, window: Duration(seconds: 3));

  List<LeagueChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initSocket();
  }

  Future<void> _initSocket() async {
    debugPrint('[LeagueChat] _initSocket() called');
    await _socketService.connect();
    debugPrint('[LeagueChat] Socket connection completed, setting up...');
    if (mounted) {
      _setupSocket();
    } else {
      debugPrint('[LeagueChat] Widget not mounted, skipping setup');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _sendThrottler.dispose();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _socketService.leaveLeague(
        leagueId: widget.leagueId,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) return;

    setState(() => _isLoading = true);
    final messages = await _chatService.getChatMessages(
      token: token,
      leagueId: widget.leagueId,
    );
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _setupSocket() {
    debugPrint('[LeagueChat] _setupSocket() called');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      debugPrint('[LeagueChat] ERROR: No user found, cannot set up socket');
      return;
    }

    debugPrint('[LeagueChat] Setting up callback for league ${widget.leagueId}');
    _socketService.onLeagueChatMessage = (message) {
      debugPrint('[LeagueChat] Message received via socket: ${message.message}');
      if (mounted) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    };

    debugPrint('[LeagueChat] Joining league ${widget.leagueId} as user ${authProvider.user!.id}');
    _socketService.joinLeague(
      leagueId: widget.leagueId,
      userId: authProvider.user!.id,
      username: authProvider.user!.username,
    );

    debugPrint('[LeagueChat] Socket listener set up for league ${widget.leagueId}');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (_messageController.text.trim().isEmpty || authProvider.user == null) {
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    debugPrint('[LeagueChat] Sending message: $message');

    _sendThrottler.call(
      () {
        debugPrint('[LeagueChat] Throttler allowed send for: $message');
        // Send via socket for real-time
        // The WebSocket will broadcast to all users including sender
        _socketService.sendLeagueChatMessage(
          leagueId: widget.leagueId,
          userId: authProvider.user!.id,
          username: authProvider.user!.username,
          message: message,
        );
      },
      onThrottled: () {
        // Show friendly message when throttled
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slow down! You\'re chatting too fast 😅'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return Positioned(
        bottom: 16,
        left: 16,
        child: FloatingActionButton(
          onPressed: () => setState(() => _isExpanded = true),
          child: const Icon(Icons.chat),
        ),
      );
    }

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat),
                    const SizedBox(width: 8),
                    const Text(
                      'League Chat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _isExpanded = false),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final authProvider = context.read<AuthProvider>();
                          final isMe = message.userId == authProvider.user?.id;

                          return _buildMessageBubble(message, isMe);
                        },
                      ),
              ),

              // Input
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(LeagueChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                message.displayUsername[0].toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: isMe ? null : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.displayUsername,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 10,
                        color: isMe
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                            : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: isMe
                                  ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                message.displayUsername[0].toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    // Less than 1 minute
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    // Less than 1 hour
    else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    // Today but more than 1 hour
    else if (messageDate == today) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
    }
    // Yesterday
    else if (diff.inDays == 1) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return 'Yesterday $hour:${time.minute.toString().padLeft(2, '0')} $period';
    }
    // Within last week
    else if (diff.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekday = weekdays[time.weekday - 1];
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$weekday $hour:${time.minute.toString().padLeft(2, '0')} $period';
    }
    // Older
    else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[time.month - 1];
      return '$month ${time.day}';
    }
  }
}
