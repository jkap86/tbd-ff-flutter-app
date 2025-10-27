import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../providers/draft_provider.dart';
import '../models/roster_model.dart';
import '../models/league_chat_message_model.dart';
import '../widgets/responsive_container.dart';
import '../services/socket_service.dart';
import '../services/league_chat_service.dart';
import 'invite_members_screen.dart';
import 'edit_league_screen.dart';
import 'draft_setup_screen.dart';
import 'draft_room_screen.dart';
import 'roster_details_screen.dart';
import 'matchups_screen.dart';

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

    await leagueProvider.loadLeagueDetails(widget.leagueId);

    // Load draft for this league to check if it exists
    await draftProvider.loadDraftByLeague(widget.leagueId);

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
    setState(() => _isChatLoading = true);
    final messages = await _chatService.getChatMessages(widget.leagueId);
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

  @override
  Widget build(BuildContext context) {
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
              RefreshIndicator(
                onRefresh: _loadLeagueDetails,
                child: ResponsiveContainer(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // League info card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                            const Divider(height: 24),
                            _buildInfoRow(
                                Icons.calendar_today, 'Season', league.season),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.category,
                              'League Type',
                              _formatLeagueType(league.leagueType),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Show Standings for in_season, Teams otherwise
                    if (league.status == 'in_season')
                      _buildStandingsSection(rosters, currentUserId, league.commissionerId ?? 0)
                    else
                      _buildTeamsSection(rosters, currentUserId, league.commissionerId ?? 0, isCommissioner, leagueProvider, authProvider),
                      ],
                    ),
                  ),
                ),
              ),
              // Matchups Button (only show after draft completes or league is in_season)
              if (league.status == 'in_season' || league.status == 'post_draft')
                Positioned(
                  bottom: 150,
                  right: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'matchups_button',
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
                    icon: const Icon(Icons.scoreboard),
                    label: const Text('Matchups'),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                ),
              // Floating Draft Button
              Positioned(
                    bottom: 80,
                    right: 16,
                    child: Consumer<DraftProvider>(
                      builder: (context, draftProvider, child) {
                        final isDrafting = league.status == 'drafting';
                        // Check if draft exists for this league
                        final hasDraft = draftProvider.currentDraft != null &&
                            draftProvider.currentDraft!.leagueId == league.id;

                        return FloatingActionButton.extended(
                          heroTag: 'draft_button',
                          onPressed: hasDraft ? () async {
                            // Go directly to draft room
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DraftRoomScreen(
                                  leagueId: league.id,
                                  leagueName: league.name,
                                ),
                              ),
                            );
                            // Reload league details when returning
                            await _loadLeagueDetails();
                          } : null, // Disabled if no draft
                          icon: Icon(
                            Icons.list_alt,
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
                          backgroundColor: hasDraft
                              ? (isDrafting
                                  ? Colors.orange
                                  : Theme.of(context).colorScheme.primaryContainer)
                              : Theme.of(context).colorScheme.surfaceVariant,
                          elevation: hasDraft ? (isDrafting ? 8 : 2) : 0,
                        );
                      },
                    ),
              ),
              // Chat Drawer (bottom)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: MediaQuery.of(context).size.height * _chatDrawerHeight,
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
                      if (_chatDrawerHeight < 0.3) {
                        _chatDrawerHeight = 0.1;
                      } else if (_chatDrawerHeight < 0.7) {
                        _chatDrawerHeight = 0.5;
                      } else {
                        _chatDrawerHeight = 0.9;
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
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
                                  children: [
                                    Text(
                                      'League Chat',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Show last message preview when collapsed
                                    if (_chatDrawerHeight <= 0.2 && _messages.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${_messages.last.displayUsername}: ${_messages.last.message}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Chat content
                        if (_chatDrawerHeight > 0.2)
                          Expanded(
                            child: Column(
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

                                            return _buildMessageBubble(message, isMe);
                                          },
                                        ),
                                ),
                                // Input
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant,
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
                      ],
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
    if (roster.starters is List) {
      for (var item in roster.starters) {
        if (item is Map && item['player'] != null) {
          starterCount++;
        }
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
                  color: Colors.blue.withOpacity(0.2),
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
                  color: Colors.green.withOpacity(0.2),
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rosters.length,
            itemBuilder: (context, index) {
              final roster = rosters[index];
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
            },
          ),
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
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rank <= 3
                        ? (rank == 1
                            ? Colors.amber
                            : rank == 2
                                ? Colors.grey.shade400
                                : Colors.brown.shade300)
                        : Theme.of(context).colorScheme.surfaceVariant,
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
                            color: Colors.blue.withOpacity(0.2),
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
                            color: Colors.green.withOpacity(0.2),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_forward_ios, size: 16),
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

  Widget _buildMessageBubble(LeagueChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
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
            if (!isMe)
              Text(
                message.displayUsername,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              message.message,
              style: TextStyle(
                color: isMe
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
