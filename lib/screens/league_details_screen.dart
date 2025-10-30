import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../providers/draft_provider.dart';
import '../models/roster_model.dart';
import '../models/league_model.dart';
import '../models/league_chat_message_model.dart';
import '../widgets/responsive_container.dart';
import '../services/socket_service.dart';
import '../services/league_chat_service.dart';
import 'invite_members_screen.dart';
import 'edit_league_screen.dart';
import 'draft_room_screen.dart';
import 'auction_draft_screen.dart';
import 'slow_auction_draft_screen.dart';
import 'roster_details_screen.dart';
import 'matchups_screen.dart';
import 'waivers/waivers_hub_screen.dart';
import 'trades_screen.dart';

class LeagueDetailsScreen extends StatefulWidget {
  final int leagueId;

  const LeagueDetailsScreen({
    super.key,
    required this.leagueId,
  });

  @override
  State<LeagueDetailsScreen> createState() => _LeagueDetailsScreenState();
}

class _LeagueDetailsScreenState extends State<LeagueDetailsScreen>
    with WidgetsBindingObserver {
  double _chatDrawerHeight = 0.1; // Start collapsed showing preview
  bool _isLeagueInfoExpanded = false;

  // Chat state
  final LeagueChatService _chatService = LeagueChatService();
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<LeagueChatMessage> _messages = [];
  bool _isChatLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLeagueDetails();
    _loadMessages();
    _setupSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload league details when app comes back to foreground
      _loadLeagueDetails();
    }
  }

  Future<void> _loadLeagueDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    final token = authProvider.token;
    if (token == null) {
      // User not authenticated, shouldn't happen but handle gracefully
      return;
    }

    await leagueProvider.loadLeagueDetails(token, widget.leagueId);

    // Load draft for this league to check if it exists
    await draftProvider.loadDraftByLeague(token, widget.leagueId);

    if (authProvider.token != null) {
      await leagueProvider.checkIsCommissioner(
        token: authProvider.token!,
        leagueId: widget.leagueId,
      );
      await leagueProvider.loadLeagueStats(
        token: authProvider.token!,
        leagueId: widget.leagueId,
      );
    }
  }

  Future<void> _loadMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) return;

    setState(() => _isChatLoading = true);
    final messages = await _chatService.getChatMessages(
      token: token,
      leagueId: widget.leagueId,
    );
    setState(() {
      _messages = messages;
      _isChatLoading = false;
    });
    _scrollToBottom();
  }

  void _setupSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    _socketService.onLeagueChatMessage = (message) {
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

    _socketService.sendLeagueChatMessage(
      leagueId: widget.leagueId,
      userId: authProvider.user!.id,
      username: authProvider.user!.username,
      message: message,
    );
  }

  // Helper method to calculate actual chat drawer height with minimum clamp
  double _getActualChatDrawerHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final calculatedHeight = screenHeight * _chatDrawerHeight;

    // Only apply minimum in landscape where screen height is limited
    // In portrait, 10% of screen is usually enough (60-90px on most devices)
    if (isLandscape) {
      return calculatedHeight.clamp(120.0, double.infinity);
    }

    return calculatedHeight;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate drawer height once per build to ensure consistency
    final drawerHeight = _getActualChatDrawerHeight(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('League Details'),
        actions: [
          Consumer2<LeagueProvider, AuthProvider>(
            builder: (context, leagueProvider, authProvider, child) {
              if (leagueProvider.isCommissioner) {
                return IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {
                    final league = leagueProvider.selectedLeague;
                    if (league != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InviteMembersScreen(
                            leagueId: league.id,
                            leagueName: league.name,
                          ),
                        ),
                      );
                    }
                  },
                  tooltip: 'Invite Members',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer2<LeagueProvider, AuthProvider>(
        builder: (context, leagueProvider, authProvider, child) {
          if (leagueProvider.status == LeagueStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (leagueProvider.status == LeagueStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    leagueProvider.errorMessage ?? 'Error loading league',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadLeagueDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final league = leagueProvider.selectedLeague;
          final rosters = leagueProvider.selectedLeagueRosters;
          final currentUserId = authProvider.user?.id;
          final isCommissioner = leagueProvider.isCommissioner;

          if (league == null) {
            return const Center(child: Text('League not found'));
          }

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: drawerHeight,
                child: ClipRect(
                  child: RefreshIndicator(
                    onRefresh: _loadLeagueDetails,
                    child: ResponsiveContainer(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header (always visible)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isLeagueInfoExpanded = !_isLeagueInfoExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                              children: [
                                Icon(
                                  Icons.sports_football,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        league.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isCommissioner)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Commissioner',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Expand/collapse icon
                                Icon(
                                  _isLeagueInfoExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                if (isCommissioner)
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit League'),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EditLeagueScreen(
                                                league: league,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.delete_forever, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete League', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                        onTap: () async {
                                          // Show confirmation dialog
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete League?'),
                                              content: const Text(
                                                'This will permanently delete the league and all related data including draft, matchups, and chat messages. This action cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(true),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            final success = await leagueProvider.deleteLeague(
                                              token: authProvider.token!,
                                              leagueId: league.id,
                                            );

                                            if (success && context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('League deleted successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              // Navigate back to leagues list
                                              Navigator.of(context).pop();
                                            } else if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(leagueProvider.errorMessage ?? 'Failed to delete league'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                            // Expandable content with animation
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: _isLeagueInfoExpanded
                                ? Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                            const Divider(height: 24),
                            _buildInfoRow(
                                Icons.calendar_today, 'Season', '${league.season} (Weeks ${league.startWeek}-${league.endWeek})'),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.sports,
                              'Season Type',
                              _formatSeasonType(league.seasonType),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.category,
                              'League Type',
                              _formatLeagueType(league.leagueType),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.emoji_events,
                              'Playoff Start',
                              'Week ${league.playoffWeekStart}',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.people,
                              'Teams',
                              '${rosters.length}/${league.totalRosters}',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.circle,
                              'Status',
                              _formatStatus(league.status),
                            ),
                            const SizedBox(height: 16),
                            // Collapsible Scoring Settings
                            _buildScoringSettingsSection(league),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            ),
                            // Footer with action buttons - Always visible
                            Consumer<DraftProvider>(
                              builder: (context, draftProvider, child) {
                                final isDrafting = league.status == 'drafting';
                                final hasDraft = draftProvider.currentDraft != null &&
                                    draftProvider.currentDraft!.leagueId == league.id;
                                final showInSeasonButtons = league.status == 'in_season' || league.status == 'post_draft';

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  width: double.infinity,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      // Draft button (always shown)
                                      SizedBox(
                                        width: 120,
                                        child: ElevatedButton.icon(
                                          onPressed: hasDraft ? () async {
                                            // Get draft to check type
                                            final draftProvider = Provider.of<DraftProvider>(context, listen: false);
                                            final draft = draftProvider.currentDraft;

                                            if (draft == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Draft not found')),
                                              );
                                              return;
                                            }

                                            // Get user's roster ID
                                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                            final userRoster = rosters.firstWhere(
                                              (r) => r.userId == authProvider.user?.id,
                                              orElse: () => rosters.first,
                                            );

                                            Widget draftScreen;
                                            if (draft.draftType == 'auction') {
                                              draftScreen = AuctionDraftScreen(
                                                draftId: draft.id,
                                                leagueId: league.id,
                                                myRosterId: userRoster.id,
                                                draftName: 'Auction Draft',
                                              );
                                            } else if (draft.draftType == 'slow_auction') {
                                              draftScreen = SlowAuctionDraftScreen(
                                                draftId: draft.id,
                                                leagueId: league.id,
                                                myRosterId: userRoster.id,
                                              );
                                            } else {
                                              // Default to snake/linear draft screen
                                              draftScreen = DraftRoomScreen(
                                                leagueId: league.id,
                                                leagueName: league.name,
                                              );
                                            }

                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => draftScreen,
                                              ),
                                            );
                                            await _loadLeagueDetails();
                                          } : null,
                                          icon: Icon(
                                            Icons.list_alt,
                                            size: 18,
                                            color: hasDraft
                                                ? (isDrafting ? Colors.white : null)
                                                : Colors.grey,
                                          ),
                                          label: Text(
                                            hasDraft ? 'Draft' : 'No Draft',
                                            style: TextStyle(
                                              color: hasDraft
                                                  ? (isDrafting ? Colors.white : null)
                                                  : Colors.grey,
                                              fontWeight: isDrafting ? FontWeight.bold : null,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hasDraft
                                                ? (isDrafting
                                                    ? Colors.orange
                                                    : Theme.of(context).colorScheme.primaryContainer)
                                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          ),
                                        ),
                                      ),
                                      // In-season buttons (Matchups, Trades, Waivers)
                                      if (showInSeasonButtons) ...[
                                        // Matchups button
                                        SizedBox(
                                          width: 130,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) => MatchupsScreen(
                                                    leagueId: league.id,
                                                    leagueName: league.name,
                                                    season: league.season,
                                                    startWeek: league.startWeek,
                                                    playoffWeekStart: league.playoffWeekStart,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.scoreboard, size: 18),
                                            label: const Text('Matchups'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                            ),
                                          ),
                                        ),
                                        // Trades button
                                        SizedBox(
                                          width: 110,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) => TradesScreen(
                                                    leagueId: league.id,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.swap_calls, size: 18),
                                            label: const Text('Trades'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                            ),
                                          ),
                                        ),
                                        // Waivers button
                                        SizedBox(
                                          width: 120,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              final userRoster = rosters.firstWhere(
                                                (r) => r.userId == currentUserId,
                                                orElse: () => rosters.first,
                                              );

                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) => WaiversHubScreen(
                                                    leagueId: league.id,
                                                    userRoster: userRoster,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.swap_horiz, size: 18),
                                            label: const Text('Waivers'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: league.status == 'in_season'
                          ? _buildStandingsSection(rosters, currentUserId, league.commissionerId ?? 0)
                          : _buildTeamsSection(rosters, currentUserId, league.commissionerId ?? 0, isCommissioner, leagueProvider, authProvider),
                      ),
                      // Add bottom padding to prevent content from going under chat drawer
                      SizedBox(height: MediaQuery.of(context).orientation == Orientation.landscape ? 8.0 : 16.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Chat Drawer (bottom)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: drawerHeight,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      final screenHeight = MediaQuery.of(context).size.height;
                      _chatDrawerHeight -= details.delta.dy / screenHeight;
                      _chatDrawerHeight = _chatDrawerHeight.clamp(0.1, 0.9);
                    });
                  },
                  onVerticalDragEnd: (details) {
                    setState(() {
                      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

                      if (isLandscape) {
                        // In landscape, use higher percentages since screen is shorter
                        if (_chatDrawerHeight < 0.35) {
                          _chatDrawerHeight = 0.1;
                        } else if (_chatDrawerHeight < 0.75) {
                          _chatDrawerHeight = 0.6; // Higher middle point for landscape
                        } else {
                          _chatDrawerHeight = 0.9;
                        }
                      } else {
                        // Portrait snap points
                        if (_chatDrawerHeight < 0.3) {
                          _chatDrawerHeight = 0.1;
                        } else if (_chatDrawerHeight < 0.7) {
                          _chatDrawerHeight = 0.5;
                        } else {
                          _chatDrawerHeight = 0.9;
                        }
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Title and Preview
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'League Chat',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Show last message preview when collapsed
                                    if (_messages.isNotEmpty) () {
                                      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                                      final threshold = isLandscape ? 0.35 : 0.2;
                                      return _chatDrawerHeight <= threshold;
                                    }()
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '${_messages.last.displayUsername}: ${_messages.last.message}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Chat content - Always use Expanded to prevent overflow
                        Expanded(
                          child: () {
                            final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                            // In landscape, need more height before showing full chat interface
                            final threshold = isLandscape ? 0.35 : 0.2;
                            return _chatDrawerHeight > threshold;
                          }()
                            ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Messages
                                Expanded(
                                  child: _isChatLoading
                                      ? const Center(child: CircularProgressIndicator())
                                      : ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.all(12),
                                          itemCount: _messages.length,
                                          itemBuilder: (context, index) {
                                            final message = _messages[index];
                                            final authProvider = context.read<AuthProvider>();
                                            final isMe = message.userId == authProvider.user?.id;

                                            return _buildMessageBubble(context, message, isMe);
                                          },
                                        ),
                                ),
                                // Input - Use SafeArea to ensure it doesn't get cut off
                                SafeArea(
                                  top: false,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _messageController,
                                            maxLines: null,
                                            minLines: 1,
                                            keyboardType: TextInputType.multiline,
                                            textInputAction: TextInputAction.newline,
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
                                ),
                              ],
                            )
                            : const SizedBox.shrink(), // Empty when collapsed
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  int _countPlayers(Roster roster) {
    // Count only non-null players in starter slots
    int starterCount = 0;
    for (var item in roster.starters) {
      if (item is Map && item['player'] != null) {
        starterCount++;
      }
    }
      return starterCount + roster.bench.length;
  }

  Widget _buildRosterCard(
    Roster roster, {
    required bool isCurrentUser,
    required bool isRosterCommissioner,
    required bool canRemove,
    required VoidCallback onRemove,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            'R${roster.rosterId}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                roster.username ?? 'Unknown User',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isRosterCommissioner)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'C',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            if (isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(roster.email ?? ''),
        trailing: canRemove
            ? IconButton(
                icon:
                    const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: onRemove,
                tooltip: 'Remove Member',
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Roster ${roster.rosterId}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_countPlayers(roster)} players',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
        onTap: () {
          final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
          final league = leagueProvider.selectedLeague;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RosterDetailsScreen(
                rosterId: roster.id,
                rosterName: roster.username ?? 'Roster ${roster.rosterId}',
                season: league?.season,
                currentWeek: league?.startWeek ?? 1,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRemoveConfirmation(
    BuildContext context,
    Roster roster,
    LeagueProvider leagueProvider,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${roster.username} from the league?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              if (authProvider.token != null) {
                final success = await leagueProvider.removeLeagueMember(
                  token: authProvider.token!,
                  leagueId: widget.leagueId,
                  userIdToRemove: roster.userId,
                );

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${roster.username} removed from league'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          leagueProvider.errorMessage ??
                              'Failed to remove member',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pre_draft':
        return 'Pre-Draft';
      case 'drafting':
        return 'Drafting';
      case 'in_season':
        return 'In Season';
      case 'complete':
        return 'Complete';
      default:
        return status;
    }
  }

  String _formatLeagueType(String type) {
    switch (type) {
      case 'redraft':
        return 'Redraft';
      case 'dynasty':
        return 'Dynasty';
      case 'keeper':
        return 'Keeper';
      default:
        return type;
    }
  }

  String _formatSeasonType(String type) {
    switch (type) {
      case 'pre':
        return 'Preseason';
      case 'regular':
        return 'Regular Season';
      case 'post':
        return 'Postseason';
      default:
        return type;
    }
  }

  Widget _buildScoringSettingsSection(League league) {
    if (league.scoringSettings == null) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Scoring Settings',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: league.scoringSettings!.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatScoringLabel(entry.key),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatScoringLabel(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildTeamsSection(
    List<Roster> rosters,
    int? currentUserId,
    int commissionerId,
    bool isCommissioner,
    LeagueProvider leagueProvider,
    AuthProvider authProvider,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Teams',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${rosters.length} teams',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rosters.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No teams in this league yet'),
              ),
            ),
          )
        else
          ...rosters.asMap().entries.map((entry) {
            final roster = entry.value;
            final isCurrentUser = roster.userId == currentUserId;
            final isRosterCommissioner = roster.userId == commissionerId;

            return _buildRosterCard(
              roster,
              isCurrentUser: isCurrentUser,
              isRosterCommissioner: isRosterCommissioner,
              canRemove: isCommissioner && !isCurrentUser,
              onRemove: () {
                _showRemoveConfirmation(
                  context,
                  roster,
                  leagueProvider,
                  authProvider,
                );
              },
            );
          }),
      ],
    );
  }

  Widget _buildStandingsSection(
    List<Roster> rosters,
    int? currentUserId,
    int commissionerId,
  ) {
    // Sort rosters by wins (descending), then by points for (descending)
    final sortedRosters = List<Roster>.from(rosters)
      ..sort((a, b) {
        final winsCompare = (b.wins ?? 0).compareTo(a.wins ?? 0);
        if (winsCompare != 0) return winsCompare;
        return (b.pointsFor ?? 0).compareTo(a.pointsFor ?? 0);
      });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Standings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${rosters.length} teams',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rosters.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No teams in this league yet'),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedRosters.length,
            itemBuilder: (context, index) {
              final roster = sortedRosters[index];
              final isCurrentUser = roster.userId == currentUserId;
              final isRosterCommissioner = roster.userId == commissionerId;
              final rank = index + 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rank <= 3
                        ? (rank == 1
                            ? Colors.amber
                            : rank == 2
                                ? Colors.grey.shade400
                                : Colors.brown.shade300)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : null,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          roster.username ?? 'Unknown User',
                          style: TextStyle(
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isRosterCommissioner)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'C',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      if (isCurrentUser)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${roster.wins ?? 0}-${roster.losses ?? 0}${roster.ties != null && roster.ties! > 0 ? '-${roster.ties}' : ''} • ${(roster.pointsFor ?? 0).toStringAsFixed(2)} PF',
                  ),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () {
                    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
                    final league = leagueProvider.selectedLeague;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RosterDetailsScreen(
                          rosterId: roster.id,
                          rosterName: roster.username ?? 'Roster ${roster.rosterId}',
                          season: league?.season,
                          currentWeek: league?.startWeek ?? 1,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMessageBubble(BuildContext context, LeagueChatMessage message, bool isMe) {
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
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.hasTradeDetails ? () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              } : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
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
                          Text(
                            widget.message.message,
                            style: TextStyle(
                              color: widget.isMe
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
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
              ),
            ),
            if (_isExpanded && widget.hasTradeDetails)
              _buildTradeDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeDetails(BuildContext context) {
    final tradeDetails = widget.message.metadata!['trade_details'] as Map<String, dynamic>;
    final items = (tradeDetails['items'] as List<dynamic>?) ?? [];

    // Handle both int and String types for roster IDs
    final proposerRosterId = tradeDetails['proposer_roster_id'] is int
        ? tradeDetails['proposer_roster_id'] as int
        : int.tryParse(tradeDetails['proposer_roster_id']?.toString() ?? '0') ?? 0;

    final receiverRosterId = tradeDetails['receiver_roster_id'] is int
        ? tradeDetails['receiver_roster_id'] as int
        : int.tryParse(tradeDetails['receiver_roster_id']?.toString() ?? '0') ?? 0;

    if (proposerRosterId == 0 || receiverRosterId == 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Unable to load trade details', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
      );
    }

    // Items FROM the proposer are what the proposer gives
    final proposerGivingItems = items.where((item) {
      final fromRosterId = item['from_roster_id'] is int
          ? item['from_roster_id'] as int
          : int.tryParse(item['from_roster_id']?.toString() ?? '0') ?? 0;
      return fromRosterId == proposerRosterId;
    }).toList();

    // Items FROM the receiver are what the receiver gives
    final receiverGivingItems = items.where((item) {
      final fromRosterId = item['from_roster_id'] is int
          ? item['from_roster_id'] as int
          : int.tryParse(item['from_roster_id']?.toString() ?? '0') ?? 0;
      return fromRosterId == receiverRosterId;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tradeDetails['proposer_team']} Gives:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (proposerGivingItems.isEmpty)
                      const Text('Nothing', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))
                    else
                      ...proposerGivingItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${item['player_name'] ?? 'Player ${item['player_id']}'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tradeDetails['receiver_team']} Gives:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (receiverGivingItems.isEmpty)
                      const Text('Nothing', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic))
                    else
                      ...receiverGivingItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${item['player_name'] ?? 'Player ${item['player_id']}'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
