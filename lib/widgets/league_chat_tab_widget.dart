import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/league_chat_message_model.dart';
import '../services/socket_service.dart';
import '../services/league_chat_service.dart';

class LeagueChatTabWidget extends StatefulWidget {
  final int leagueId;

  const LeagueChatTabWidget({
    super.key,
    required this.leagueId,
  });

  @override
  State<LeagueChatTabWidget> createState() => _LeagueChatTabWidgetState();
}

class _LeagueChatTabWidgetState extends State<LeagueChatTabWidget> {
  final LeagueChatService _chatService = LeagueChatService();
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<LeagueChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
    setState(() => _isLoading = true);
    final messages = await _chatService.getChatMessages(widget.leagueId);
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _setupSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    _socketService.onLeagueChatMessage = (message) {
      if (!mounted) return;
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    };

    _socketService.joinLeague(
      leagueId: widget.leagueId,
      userId: authProvider.user!.id,
      username: authProvider.user!.username,
    );
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

    // Send via socket for real-time
    // The WebSocket will broadcast to all users including sender
    _socketService.sendLeagueChatMessage(
      leagueId: widget.leagueId,
      userId: authProvider.user!.id,
      username: authProvider.user!.username,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
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
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: null,
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
    );
  }

  Widget _buildMessageBubble(LeagueChatMessage message, bool isMe) {
    final hasTradeDetails = message.metadata != null &&
                            message.metadata!['show_details'] == true &&
                            message.metadata!['trade_details'] != null;

    return _TradeNotificationBubble(
      message: message,
      isMe: isMe,
      hasTradeDetails: hasTradeDetails,
    );
  }
}

class _TradeNotificationBubble extends StatefulWidget {
  final LeagueChatMessage message;
  final bool isMe;
  final bool hasTradeDetails;

  const _TradeNotificationBubble({
    required this.message,
    required this.isMe,
    required this.hasTradeDetails,
  });

  @override
  State<_TradeNotificationBubble> createState() => _TradeNotificationBubbleState();
}

class _TradeNotificationBubbleState extends State<_TradeNotificationBubble> {
  bool _isExpanded = false;
  int? _selectedVote; // 1-5, null if not voted

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main message bubble
            InkWell(
              onTap: widget.hasTradeDetails
                  ? () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isMe)
                      Text(
                        widget.message.displayUsername,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    if (!widget.isMe) const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.message.message,
                            style: TextStyle(
                              color: widget.isMe
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (widget.hasTradeDetails) ...[
                          const SizedBox(width: 8),
                          Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: widget.isMe
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Expandable trade details
            if (widget.hasTradeDetails && _isExpanded)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTradeDetails(context),
                    // Add voting UI for completed trades
                    if (_isCompletedTrade()) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _buildVotingSection(context),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isCompletedTrade() {
    // Check if the message is about a completed trade
    return widget.message.message.toLowerCase().contains('trade completed');
  }

  Widget _buildTradeDetails(BuildContext context) {
    final tradeDetails = widget.message.metadata!['trade_details'] as Map<String, dynamic>;
    final proposerTeamName = tradeDetails['proposer_team'] as String? ?? 'Team';
    final receiverTeamName = tradeDetails['receiver_team'] as String? ?? 'Team';
    final proposerRosterId = tradeDetails['proposer_roster_id'] is int
        ? tradeDetails['proposer_roster_id'] as int
        : int.tryParse(tradeDetails['proposer_roster_id']?.toString() ?? '0') ?? 0;
    final receiverRosterId = tradeDetails['receiver_roster_id'] is int
        ? tradeDetails['receiver_roster_id'] as int
        : int.tryParse(tradeDetails['receiver_roster_id']?.toString() ?? '0') ?? 0;
    final items = tradeDetails['items'] as List<dynamic>? ?? [];

    // Items FROM the proposer are what the proposer gives
    final proposerItems = items.where((item) {
      final fromRosterId = item['from_roster_id'] is int
          ? item['from_roster_id'] as int
          : int.tryParse(item['from_roster_id']?.toString() ?? '0') ?? 0;
      return fromRosterId == proposerRosterId;
    }).toList();

    // Items FROM the receiver are what the receiver gives
    final receiverItems = items.where((item) {
      final fromRosterId = item['from_roster_id'] is int
          ? item['from_roster_id'] as int
          : int.tryParse(item['from_roster_id']?.toString() ?? '0') ?? 0;
      return fromRosterId == receiverRosterId;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Proposer gives
        Text(
          '$proposerTeamName gives:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: widget.isMe
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        if (proposerItems.isEmpty)
          Text(
            '  • Nothing',
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          )
        else
          ...proposerItems.map((item) {
            final playerName = item['player_name'] as String? ?? 'Unknown Player';
            return Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• $playerName',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isMe
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        // Receiver gives
        Text(
          '$receiverTeamName gives:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: widget.isMe
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        if (receiverItems.isEmpty)
          Text(
            '  • Nothing',
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          )
        else
          ...receiverItems.map((item) {
            final playerName = item['player_name'] as String? ?? 'Unknown Player';
            return Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                '• $playerName',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isMe
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildVotingSection(BuildContext context) {
    final tradeDetails = widget.message.metadata!['trade_details'] as Map<String, dynamic>;
    final proposerTeamName = tradeDetails['proposer_team'] as String? ?? 'Team 1';
    final receiverTeamName = tradeDetails['receiver_team'] as String? ?? 'Team 2';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who won this trade?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: widget.isMe
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        // Vote buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildVoteButton(context, 1, proposerTeamName, 'Lopsided'),
            _buildVoteButton(context, 2, proposerTeamName, 'Favor'),
            _buildVoteButton(context, 3, 'Fair', 'Trade'),
            _buildVoteButton(context, 4, receiverTeamName, 'Favor'),
            _buildVoteButton(context, 5, receiverTeamName, 'Lopsided'),
          ],
        ),
      ],
    );
  }

  Widget _buildVoteButton(BuildContext context, int value, String team, String label) {
    final isSelected = _selectedVote == value;
    final color = widget.isMe
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedVote = value;
            });
            // TODO: Send vote to backend
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? (widget.isMe
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                      : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3))
                  : Colors.transparent,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (value != 3)
                  Text(
                    team,
                    style: TextStyle(
                      fontSize: 8,
                      color: color.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
