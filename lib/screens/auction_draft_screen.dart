import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/spacing.dart';
import '../models/auction_model.dart';
import '../models/player_model.dart';
import '../models/draft_model.dart';
import '../providers/auction_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/league_chat_tab_widget.dart';

class AuctionDraftScreen extends StatefulWidget {
  final int draftId;
  final int leagueId;
  final int myRosterId;
  final String draftName;

  const AuctionDraftScreen({
    super.key,
    required this.draftId,
    required this.leagueId,
    required this.myRosterId,
    required this.draftName,
  });

  @override
  State<AuctionDraftScreen> createState() => _AuctionDraftScreenState();
}

class _AuctionDraftScreenState extends State<AuctionDraftScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPosition;
  Timer? _timer;
  double _drawerHeight = 0.5; // Start at 50%

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild to update preview section when tab changes
      }
    });
    _loadAuctionData();
    _setupTimer();
  }

  Future<void> _loadAuctionData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final auctionProvider =
        Provider.of<AuctionProvider>(context, listen: false);

    // Setup socket listeners
    await auctionProvider.setupSlowAuctionListeners(
        widget.draftId, widget.myRosterId);

    // Load initial data
    await auctionProvider.loadAuctionData(
      token: authProvider.token!,
      draftId: widget.draftId,
      myRosterId: widget.myRosterId,
      leagueId: widget.leagueId,
    );
  }

  void _setupTimer() {
    // Refresh UI every second for countdown timers
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.draftName),
        elevation: 0,
      ),
      body: Consumer<AuctionProvider>(
        builder: (context, auctionProvider, _) {
          if (auctionProvider.status == AuctionStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (auctionProvider.status == AuctionStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    auctionProvider.errorMessage ?? 'An error occurred',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: Spacing.lg),
                  ElevatedButton(
                    onPressed: _loadAuctionData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final activeNominations = auctionProvider.activeNominations;
          final currentNomination =
              activeNominations.isNotEmpty ? activeNominations.first : null;
          final draft = auctionProvider.draft;

          final screenHeight = MediaQuery.of(context).size.height;
          final appBarHeight = AppBar().preferredSize.height +
              MediaQuery.of(context).padding.top;
          final availableHeight = screenHeight - appBarHeight;

          return LayoutBuilder(
            builder: (context, constraints) {
              // Drawer can expand up to 95% of available height (stops below grid header)
              // Minimum height to show drag handle + nomination section + tabs
              final minDrawerHeightPixels = currentNomination != null ? 200.0 : 100.0;
              final minDrawerHeightPercent = minDrawerHeightPixels / availableHeight;
              final drawerHeightPixels = (availableHeight * _drawerHeight)
                  .clamp(minDrawerHeightPixels, availableHeight * 0.95);

              return Column(
                children: [
                  // Grid header only - always visible
                  _buildGridHeader(auctionProvider, draft),

                  // Expandable area with grid body and drawer (on same level)
                  Expanded(
                    child: Stack(
                      children: [
                        // Grid body - behind drawer
                        _buildGridBody(auctionProvider, draft),

                        // Manual draggable drawer - covers grid body
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: drawerHeightPixels,
                          child: GestureDetector(
                            onVerticalDragUpdate: (details) {
                              setState(() {
                                final screenHeight =
                                    MediaQuery.of(context).size.height;
                                _drawerHeight -=
                                    details.delta.dy / screenHeight;
                                _drawerHeight = _drawerHeight.clamp(minDrawerHeightPercent, 0.95);
                              });
                            },
                            onVerticalDragEnd: (details) {
                              // Snap to nearest position
                              setState(() {
                                final midPoint = (minDrawerHeightPercent + 0.95) / 2;
                                if (_drawerHeight < midPoint) {
                                  _drawerHeight = minDrawerHeightPercent;
                                } else {
                                  _drawerHeight = 0.95;
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Drag handle
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: Spacing.lg),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade400,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          const SizedBox(height: Spacing.xs),
                                          Text(
                                            'Drag to expand',
                                            style: TextStyle(
                                              fontSize: FontSizes.small,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Current nomination section at top of drawer
                                  if (currentNomination != null)
                                    _buildNominationSection(auctionProvider, currentNomination, draft),
                                  // Tabs - always visible
                                  TabBar(
                                    controller: _tabController,
                                    tabs: const [
                                      Tab(text: 'Available Players'),
                                      Tab(text: 'Chat'),
                                    ],
                                    labelColor:
                                        Theme.of(context).primaryColor,
                                    unselectedLabelColor: Colors.grey,
                                  ),
                                  // Tab content - always show, will clip when collapsed
                                  Expanded(
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _buildAvailablePlayersTab(
                                            auctionProvider),
                                        _buildChatTab(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGridHeader(AuctionProvider auctionProvider, Draft? draft) {
    final rosters = auctionProvider.auctionRosters;

    if (rosters.isEmpty || draft == null) {
      return const SizedBox.shrink();
    }

    final currentRosterId = draft.currentRosterId;

    // Build just the header row of the DataTable
    return Container(
      width: double.infinity,
      color: Colors.grey.shade200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width,
          ),
          child: DataTable(
            headingRowHeight: 70,
            columnSpacing: Spacing.lg,
            horizontalMargin: Spacing.md,
            columns: [
              const DataColumn(
                label: Center(
                  child: Text(
                    'Slot',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ...rosters.map((roster) {
                final teamName =
                    roster['team_name'] ?? 'Team ${roster['roster_id']}';
                final isMyRoster = roster['id'] == widget.myRosterId;
                final isNominating = roster['id'] == currentRosterId;
                final budget = roster['budget'] as Map<String, dynamic>?;

                return DataColumn(
                  label: Container(
                    constraints: const BoxConstraints(minWidth: 120),
                    padding:
                        const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.md),
                    decoration: BoxDecoration(
                      color: isNominating
                          ? Colors.green.shade100
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                teamName,
                                style: TextStyle(
                                  fontSize: FontSizes.subtitle,
                                  fontWeight: isMyRoster
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isNominating
                                      ? Colors.green.shade900
                                      : (isMyRoster ? Colors.blue : Colors.black),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMyRoster) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: FontSizes.small,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (isNominating) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.gavel,
                                  size: 16, color: Colors.green),
                            ],
                          ],
                        ),
                        if (budget != null) ...[
                          const SizedBox(height: Spacing.xs),
                          Text(
                            '\$${budget['available']} left',
                            style: TextStyle(
                              fontSize: FontSizes.small,
                              fontWeight: FontWeight.w500,
                              color: isNominating
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
            rows: const [], // No rows, header only
          ),
        ),
      ),
    );
  }

  Widget _buildGridBody(AuctionProvider auctionProvider, Draft? draft) {
    final rosters = auctionProvider.auctionRosters;

    if (rosters.isEmpty || draft == null) {
      return const SizedBox.shrink();
    }

    final rosterSlots = [
      'QB',
      'RB1',
      'RB2',
      'WR1',
      'WR2',
      'WR3',
      'TE',
      'FLEX',
      'K',
      'DEF',
      'BN1',
      'BN2',
      'BN3',
      'BN4',
      'BN5'
    ];
    final currentRosterId = draft.currentRosterId;

    return Container(
      width: double.infinity,
      color: Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
            ),
            child: DataTable(
              headingRowHeight: 0, // Hide header since it's shown separately
              columnSpacing: Spacing.md,
              horizontalMargin: Spacing.sm,
              columns: [
                const DataColumn(label: SizedBox.shrink()),
                ...rosters.map(
                    (roster) => const DataColumn(label: SizedBox.shrink())),
              ],
              rows: List.generate(rosterSlots.length, (slotIndex) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        rosterSlots[slotIndex],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ...rosters.map((roster) {
                      final players = roster['players'] as List<dynamic>? ?? [];
                      final isNominating = roster['id'] == currentRosterId;

                      if (slotIndex < players.length) {
                        final player = players[slotIndex];
                        final playerName = player['full_name'] ?? 'Unknown';
                        final position = player['position'] ?? '';
                        final winningBid = player['winning_bid'] ?? 0;

                        return DataCell(
                          Container(
                            padding: const EdgeInsets.all(Spacing.xs),
                            decoration: BoxDecoration(
                              color: isNominating
                                  ? Colors.green.shade50
                                  : Colors.transparent,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playerName,
                                  style: const TextStyle(
                                    fontSize: FontSizes.small,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$position - \$$winningBid',
                                  style: TextStyle(
                                    fontSize: FontSizes.small,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return DataCell(
                          Container(
                            padding: const EdgeInsets.all(Spacing.xs),
                            decoration: BoxDecoration(
                              color: isNominating
                                  ? Colors.green.shade50
                                  : Colors.transparent,
                            ),
                            child: Text(
                              '-',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ),
                        );
                      }
                    }),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNominationSection(
      AuctionProvider auctionProvider, AuctionNomination nomination, Draft? draft) {
    final minBid = draft?.minBid ?? 1;
    final currentBid = nomination.winningBid ?? 0;
    final nextMinBid = currentBid > 0 ? currentBid + 1 : minBid;
    final myBudget = auctionProvider.myBudget;
    final isMyNomination = nomination.nominatingRosterId == widget.myRosterId;
    final isMyWinningBid = nomination.winningRosterId == widget.myRosterId;
    final timeRemaining = nomination.timeRemaining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: Spacing.xs,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player info section
          Text(
            nomination.playerName ?? 'Unknown Player',
            style: const TextStyle(
              fontSize: FontSizes.title,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            nomination.playerPositionTeam,
            style: TextStyle(
              fontSize: FontSizes.subtitle,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: Spacing.lg),

          // Bid and Timer section
          Row(
            children: [
              // Current bid container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: isMyWinningBid ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(
                      color: isMyWinningBid ? Colors.green.shade300 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Current Bid',
                        style: TextStyle(
                          fontSize: FontSizes.small,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        '\$${currentBid > 0 ? currentBid : minBid}',
                        style: TextStyle(
                          fontSize: FontSizes.heading,
                          fontWeight: FontWeight.bold,
                          color: isMyWinningBid ? Colors.green.shade700 : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: Spacing.md),

              // Timer container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: timeRemaining.inHours < 1 ? Colors.red.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(
                      color: timeRemaining.inHours < 1 ? Colors.red.shade300 : Colors.orange.shade300,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 20,
                        color: timeRemaining.inHours < 1 ? Colors.red.shade700 : Colors.orange.shade700,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        _formatDuration(timeRemaining),
                        style: TextStyle(
                          fontSize: FontSizes.body,
                          fontWeight: FontWeight.bold,
                          color: timeRemaining.inHours < 1 ? Colors.red.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: Spacing.lg),

          // Bidding button or status
          if (myBudget != null && !isMyNomination)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: myBudget.canAfford(nextMinBid)
                    ? () => _placeBidOnNomination(nomination.id, nextMinBid)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMyWinningBid ? Colors.orange : Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
                  minimumSize: const Size(100, TouchTargets.minimum),
                ),
                child: Text(
                  isMyWinningBid ? 'Raise to \$${nextMinBid}' : 'Bid \$${nextMinBid}',
                  style: const TextStyle(
                    fontSize: FontSizes.body,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else if (isMyNomination)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Text(
                'Your Nomination',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: FontSizes.body,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  void _placeBidOnNomination(int nominationId, int bidAmount) async {
    try {
      // TODO: Implement bidding via auction service
      // await _auctionService.placeBid(nominationId, bidAmount);
      debugPrint('Placing bid: \$${bidAmount} on nomination ${nominationId}');
    } catch (e) {
      debugPrint('Error placing bid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place bid: $e')),
        );
      }
    }
  }

  Widget _buildAvailablePlayersTab(AuctionProvider auctionProvider) {
    final filteredPlayers = _filterPlayers(auctionProvider.availablePlayers);

    return Column(
      children: [
        // Search and filter
        Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search players...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              DropdownButton<String>(
                value: _selectedPosition,
                hint: const Text('Position'),
                items: ['ALL', 'QB', 'RB', 'WR', 'TE', 'K', 'DEF']
                    .map((pos) => DropdownMenuItem(
                          value: pos == 'ALL' ? null : pos,
                          child: Text(pos),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPosition = value;
                  });
                },
              ),
            ],
          ),
        ),
        // Player list
        Expanded(
          child: filteredPlayers.isEmpty
              ? const Center(child: Text('No players available'))
              : ListView.builder(
                  itemCount: filteredPlayers.length,
                  itemBuilder: (context, index) {
                    final player = filteredPlayers[index];
                    final isLast = index == filteredPlayers.length - 1;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                          title: Text(
                            player.displayName,
                            style: const TextStyle(
                              fontSize: FontSizes.body,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: Spacing.xs),
                            child: Text(
                              player.positionTeam,
                              style: const TextStyle(fontSize: FontSizes.subtitle),
                            ),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _nominatePlayer(player),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: Spacing.md),
                              minimumSize: const Size(100, TouchTargets.minimum),
                            ),
                            child: const Text(
                              'Nominate',
                              style: TextStyle(
                                fontSize: FontSizes.body,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: Spacing.lg,
                            endIndent: Spacing.lg,
                            color: Colors.grey.shade300,
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActivityTab(AuctionProvider auctionProvider) {
    final activities = auctionProvider.activityFeed;

    if (activities.isEmpty) {
      return const Center(child: Text('No activity yet'));
    }

    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        IconData icon;
        Color color;

        switch (activity.type) {
          case 'nomination':
            icon = Icons.person_add;
            color = Colors.blue;
            break;
          case 'bid':
            icon = Icons.gavel;
            color = Colors.orange;
            break;
          case 'won':
            icon = Icons.check_circle;
            color = Colors.green;
            break;
          case 'expired':
            icon = Icons.timer_off;
            color = Colors.grey;
            break;
          default:
            icon = Icons.info;
            color = Colors.grey;
        }

        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(activity.description),
          subtitle: Text(_formatTime(activity.timestamp)),
        );
      },
    );
  }

  Widget _buildChatTab() {
    return LeagueChatTabWidget(leagueId: widget.leagueId);
  }

  List<Player> _filterPlayers(List<Player> players) {
    var filtered = players;

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final search = _searchController.text.toLowerCase();
      filtered = filtered
          .where((p) => p.displayName.toLowerCase().contains(search))
          .toList();
    }

    // Filter by position
    if (_selectedPosition != null) {
      filtered =
          filtered.where((p) => p.position == _selectedPosition).toList();
    }

    return filtered;
  }

  void _nominatePlayer(Player player) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final auctionProvider =
        Provider.of<AuctionProvider>(context, listen: false);

    final success = await auctionProvider.nominatePlayer(
      authProvider.token!,
      widget.draftId,
      player.playerId,
      widget.myRosterId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${player.displayName} nominated!')),
      );
      _tabController.animateTo(2); // Switch to bid history tab
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auctionProvider.errorMessage ?? 'Failed to nominate player',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _placeBid(int maxBid, int nominationId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final auctionProvider =
        Provider.of<AuctionProvider>(context, listen: false);

    final success = await auctionProvider.placeBid(
      authProvider.token!,
      nominationId,
      widget.myRosterId,
      maxBid,
      widget.draftId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid placed!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auctionProvider.errorMessage ?? 'Failed to place bid',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Widget _buildDraftControls(Draft draft, AuctionProvider auctionProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Draft status
          Row(
            children: [
              Icon(
                draft.status == 'in_progress'
                    ? Icons.play_circle_filled
                    : draft.status == 'paused'
                        ? Icons.pause_circle_filled
                        : Icons.circle,
                color: draft.status == 'in_progress'
                    ? Colors.green
                    : draft.status == 'paused'
                        ? Colors.orange
                        : Colors.grey,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                draft.status == 'in_progress'
                    ? 'In Progress'
                    : draft.status == 'paused'
                        ? 'Paused'
                        : 'Not Started',
                style: const TextStyle(
                  fontSize: FontSizes.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Control buttons
          Row(
            children: [
              if (draft.status == 'not_started')
                ElevatedButton.icon(
                  onPressed: () => _startDraft(auctionProvider),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (draft.status == 'in_progress')
                ElevatedButton.icon(
                  onPressed: () => _pauseDraft(auctionProvider),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (draft.status == 'paused')
                ElevatedButton.icon(
                  onPressed: () => _resumeDraft(auctionProvider),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _startDraft(AuctionProvider auctionProvider) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await auctionProvider.startDraft(
      authProvider.token!,
      widget.draftId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft started!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(auctionProvider.errorMessage ?? 'Failed to start draft'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _pauseDraft(AuctionProvider auctionProvider) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await auctionProvider.pauseDraft(
      authProvider.token!,
      widget.draftId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft paused!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(auctionProvider.errorMessage ?? 'Failed to pause draft'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resumeDraft(AuctionProvider auctionProvider) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await auctionProvider.resumeDraft(
      authProvider.token!,
      widget.draftId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft resumed!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(auctionProvider.errorMessage ?? 'Failed to resume draft'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Budget Display Widget
class BudgetDisplayWidget extends StatelessWidget {
  final RosterBudget budget;

  const BudgetDisplayWidget({
    super.key,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final showReserved = budget.reserved > 0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBudgetItem(
            context,
            'Budget',
            '\$${budget.startingBudget}',
            theme.colorScheme.onSurfaceVariant,
          ),
          _buildBudgetItem(
            context,
            'Spent',
            '\$${budget.spent}',
            theme.colorScheme.error,
          ),
          if (showReserved)
            _buildBudgetItem(
              context,
              'Reserved',
              '\$${budget.reserved}',
              theme.colorScheme.tertiary,
            ),
          _buildBudgetItem(
            context,
            'Available',
            '\$${budget.available}',
            isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: FontSizes.small,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 22 : FontSizes.title,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Current Nomination Widget
class CurrentNominationWidget extends StatefulWidget {
  final AuctionNomination nomination;
  final List<AuctionBid> bidHistory;
  final Function(int maxBid) onPlaceBid;
  final bool isMyBid;

  const CurrentNominationWidget({
    super.key,
    required this.nomination,
    required this.bidHistory,
    required this.onPlaceBid,
    required this.isMyBid,
  });

  @override
  State<CurrentNominationWidget> createState() =>
      _CurrentNominationWidgetState();
}

class _CurrentNominationWidgetState extends State<CurrentNominationWidget> {
  final TextEditingController _bidController = TextEditingController();
  double _sliderValue = 0;

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CurrentNominationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nomination.id != widget.nomination.id) {
      // Reset slider when nomination changes
      final currentBid = widget.nomination.winningBid ?? 0;
      setState(() {
        _sliderValue = (currentBid + 1).toDouble();
        _bidController.text = (currentBid + 1).toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBid = widget.nomination.winningBid ?? 0;

    // Initialize slider if not set or if it's below minimum
    if (_sliderValue < (currentBid + 1)) {
      _sliderValue = (currentBid + 1).toDouble();
      if (_bidController.text.isEmpty) {
        _bidController.text = (currentBid + 1).toString();
      }
    }

    // Use StreamBuilder to update timer every second
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final timeRemaining = widget.nomination.timeRemaining;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Player card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      children: [
                        Text(
                          widget.nomination.playerName ?? 'Unknown Player',
                          style: const TextStyle(
                            fontSize: FontSizes.heading,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          widget.nomination.playerPositionTeam,
                          style: TextStyle(
                            fontSize: FontSizes.body,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (widget.nomination.nominatingTeamName != null) ...[
                          const SizedBox(height: Spacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'Nominated by ${widget.nomination.nominatingTeamName}',
                              style: TextStyle(
                                fontSize: FontSizes.subtitle,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                // Current bid info
                Card(
                  color: widget.isMyBid ? Colors.green.shade50 : null,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Bid',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: FontSizes.body,
                                  ),
                                ),
                                Text(
                                  '\$$currentBid',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.nomination.deadline != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Time Remaining',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: FontSizes.body,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(timeRemaining),
                                    style: TextStyle(
                                      fontSize: FontSizes.heading,
                                      fontWeight: FontWeight.bold,
                                      color: timeRemaining.inSeconds < 30
                                          ? Colors.red
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'No Time Limit',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: FontSizes.body,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (widget.nomination.winningTeamName != null) ...[
                          const SizedBox(height: Spacing.sm),
                          Text(
                            'Winning Team: ${widget.nomination.winningTeamName}',
                            style: TextStyle(
                              color: widget.isMyBid
                                  ? Colors.green
                                  : Colors.grey.shade700,
                              fontWeight: widget.isMyBid
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                // Bidding controls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Place Your Bid',
                          style: TextStyle(
                            fontSize: FontSizes.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),
                        // Bid amount display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Bid:',
                              style: TextStyle(fontSize: FontSizes.body),
                            ),
                            Text(
                              '\$${_sliderValue.round()}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        // Slider
                        Slider(
                          value: _sliderValue,
                          min: (currentBid + 1).toDouble(),
                          max: (currentBid + 100).toDouble(),
                          divisions: 99,
                          label: '\$${_sliderValue.round()}',
                          onChanged: (value) {
                            setState(() {
                              _sliderValue = value;
                              _bidController.text = value.round().toString();
                            });
                          },
                        ),
                        // Min and max labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${currentBid + 1}',
                              style: TextStyle(
                                fontSize: FontSizes.small,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '\$${currentBid + 100}',
                              style: TextStyle(
                                fontSize: FontSizes.small,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.lg),
                        const Divider(),
                        const SizedBox(height: Spacing.sm),
                        const Text(
                          'Or enter exact amount',
                          style: TextStyle(fontSize: FontSizes.body),
                        ),
                        const SizedBox(height: Spacing.sm),
                        TextField(
                          controller: _bidController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter bid amount',
                            prefixText: '\$ ',
                            border: const OutlineInputBorder(),
                            helperText: 'Minimum: \$${currentBid + 1}',
                          ),
                          onChanged: (value) {
                            final amount = int.tryParse(value);
                            if (amount != null) {
                              setState(() {
                                _sliderValue = amount.toDouble().clamp(
                                      (currentBid + 1).toDouble(),
                                      (currentBid + 100).toDouble(),
                                    );
                              });
                            }
                          },
                        ),
                        const SizedBox(height: Spacing.lg),
                        ElevatedButton(
                          onPressed: _placeBid,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          child: const Text(
                            'Place Bid',
                            style: TextStyle(
                              fontSize: FontSizes.title,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _placeBid() {
    int? bidAmount;

    if (_bidController.text.isNotEmpty) {
      bidAmount = int.tryParse(_bidController.text);
    } else {
      bidAmount = _sliderValue.round();
    }

    if (bidAmount == null || bidAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid bid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentBid = widget.nomination.winningBid ?? 0;
    if (bidAmount <= currentBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bid must be greater than current bid (\$$currentBid)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onPlaceBid(bidAmount);

    // Reset slider and clear input
    setState(() {
      _sliderValue = (currentBid + 1).toDouble();
      _bidController.clear();
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative || duration.inSeconds == 0) {
      return '0:00';
    }

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Bid History Widget
class BidHistoryWidget extends StatelessWidget {
  final List<AuctionBid> bids;

  const BidHistoryWidget({
    super.key,
    required this.bids,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return const Center(
        child: Text('No bids yet'),
      );
    }

    // Sort bids by amount descending (highest first)
    final sortedBids = List<AuctionBid>.from(bids)
      ..sort((a, b) => b.bidAmount.compareTo(a.bidAmount));

    return ListView.builder(
      itemCount: sortedBids.length,
      itemBuilder: (context, index) {
        final bid = sortedBids[index];
        return ListTile(
          leading: Icon(
            bid.isWinning ? Icons.check_circle : Icons.circle_outlined,
            color: bid.isWinning ? Colors.green : Colors.grey,
          ),
          title: Text(
            '${bid.teamName ?? 'Unknown Team'}: \$${bid.bidAmount}',
            style: TextStyle(
              fontWeight: bid.isWinning ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(_formatTime(bid.createdAt)),
          trailing: bid.isWinning
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: const Text(
                    'WINNING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: FontSizes.small,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
