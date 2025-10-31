import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auction_model.dart';
import '../models/player_model.dart';
import '../providers/auction_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/nomination_grid_widget.dart';
import '../widgets/nomination_detail_dialog.dart';

class SlowAuctionDraftScreen extends StatefulWidget {
  final int draftId;
  final int leagueId;
  final int myRosterId;

  const SlowAuctionDraftScreen({
    Key? key,
    required this.draftId,
    required this.leagueId,
    required this.myRosterId,
  }) : super(key: key);

  @override
  State<SlowAuctionDraftScreen> createState() => _SlowAuctionDraftScreenState();
}

class _SlowAuctionDraftScreenState extends State<SlowAuctionDraftScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final authProvider = context.read<AuthProvider>();
    final auctionProvider = context.read<AuctionProvider>();

    if (authProvider.token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication required')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // Setup socket listeners
    await auctionProvider.setupSlowAuctionListeners(widget.draftId, widget.myRosterId);

    // Load initial data
    await auctionProvider.loadAuctionData(
      token: authProvider.token!,
      draftId: widget.draftId,
      myRosterId: widget.myRosterId,
      leagueId: widget.leagueId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slow Auction Draft'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Column(
            children: [
              _buildBudgetBar(),
              TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).colorScheme.secondary,
                tabs: const [
                  Tab(text: 'Active Bids'),
                  Tab(text: 'Available'),
                  Tab(text: 'Activity'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveNominationsTab(),
                _buildAvailablePlayersTab(),
                _buildActivityTab(),
              ],
            ),
      floatingActionButton: _buildNominateButton(),
    );
  }

  Widget _buildBudgetBar() {
    return Consumer<AuctionProvider>(
      builder: (context, auctionProvider, child) {
        final budget = auctionProvider.myBudget;
        final winningCount = auctionProvider.myWinningNominationsCount ?? 0;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              _buildBudgetStat(
                context,
                'Budget',
                budget != null ? '\$${budget.available}' : '-',
                Icons.account_balance_wallet,
              ),
              _buildBudgetStat(
                context,
                'Spent',
                budget != null ? '\$${budget.spent}' : '-',
                Icons.shopping_cart,
              ),
              _buildBudgetStat(
                context,
                'Active Bids',
                budget != null ? '\$${budget.activeBids}' : '-',
                Icons.gavel,
              ),
              _buildBudgetStat(
                context,
                'Winning',
                '$winningCount',
                Icons.emoji_events,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetStat(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveNominationsTab() {
    return Consumer<AuctionProvider>(
      builder: (context, auctionProvider, child) {
        final nominations = auctionProvider.activeNominations;

        return Column(
          children: [
            if (nominations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${nominations.length} active nomination${nominations.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            Expanded(
              child: NominationGridWidget(
                nominations: nominations,
                myRosterId: widget.myRosterId,
                onTapNomination: (nomination) => _showNominationDetail(nomination),
                onPlaceBid: (nomination) => _showBidDialog(nomination),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvailablePlayersTab() {
    return Consumer<AuctionProvider>(
      builder: (context, auctionProvider, child) {
        final players = auctionProvider.availablePlayers;

        if (players.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No available players',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildPlayerFilters(),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(player.position.substring(0, 1)),
                    ),
                    title: Text(player.fullName),
                    subtitle: Text(player.positionTeam),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () => _nominatePlayer(player),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerFilters() {
    // TODO: Add position/team filters
    return Container(
      padding: const EdgeInsets.all(8),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Search players...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          final authProvider = context.read<AuthProvider>();
          if (authProvider.token != null) {
            context.read<AuctionProvider>().filterPlayers(
                  token: authProvider.token!,
                  draftId: widget.draftId,
                  search: value.isEmpty ? null : value,
                );
          }
        },
      ),
    );
  }

  Widget _buildActivityTab() {
    return Consumer<AuctionProvider>(
      builder: (context, auctionProvider, child) {
        final activities = auctionProvider.activityFeed;

        if (activities.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No activity yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ListTile(
              leading: _getActivityIcon(activity.type),
              title: Text(activity.description),
              subtitle: Text(_timeAgo(activity.timestamp)),
            );
          },
        );
      },
    );
  }

  Widget _getActivityIcon(String type) {
    switch (type) {
      case 'nomination':
        return const Icon(Icons.person_add, color: Colors.blue);
      case 'bid':
        return const Icon(Icons.gavel, color: Colors.orange);
      case 'won':
        return const Icon(Icons.emoji_events, color: Colors.green);
      case 'expired':
        return const Icon(Icons.timer_off, color: Colors.red);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget? _buildNominateButton() {
    // TODO: Check max simultaneous nominations from draft settings
    return FloatingActionButton.extended(
      onPressed: _showNominatePlayerDialog,
      icon: const Icon(Icons.add),
      label: const Text('Nominate'),
    );
  }

  Future<void> _showNominatePlayerDialog() async {
    // Switch to available players tab
    _tabController.animateTo(1);
  }

  Future<void> _nominatePlayer(Player player) async {
    final authProvider = context.read<AuthProvider>();
    final auctionProvider = context.read<AuctionProvider>();

    if (authProvider.token == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nominate Player'),
        content: Text('Nominate ${player.fullName} for auction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nominate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await auctionProvider.nominatePlayer(
      authProvider.token!,
      widget.draftId,
      player.playerId,
      widget.myRosterId,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${player.fullName} nominated!')),
        );
        // Switch to active nominations tab
        _tabController.animateTo(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auctionProvider.errorMessage ?? 'Failed to nominate player'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNominationDetail(AuctionNomination nomination) {
    final auctionProvider = context.read<AuctionProvider>();
    final bids = auctionProvider.getBidsForNomination(nomination.id);
    final budget = auctionProvider.myBudget;

    showDialog(
      context: context,
      builder: (context) => NominationDetailDialog(
        nomination: nomination,
        bidHistory: bids,
        myRosterId: widget.myRosterId,
        availableBudget: budget?.available,
        onPlaceBid: (maxBid) async {
          final authProvider = context.read<AuthProvider>();
          if (authProvider.token == null) return;

          final success = await auctionProvider.placeBid(
            authProvider.token!,
            nomination.id,
            widget.myRosterId,
            maxBid,
            widget.draftId,
          );

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bid placed!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(auctionProvider.errorMessage ?? 'Failed to place bid'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showBidDialog(AuctionNomination nomination) {
    final auctionProvider = context.read<AuctionProvider>();
    final budget = auctionProvider.myBudget;
    final currentBid = nomination.winningBid ?? 0;
    final minBid = currentBid + 1;

    final TextEditingController maxBidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bid on ${nomination.playerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current bid: \$${currentBid}'),
            Text('Minimum bid: \$${minBid}'),
            if (budget != null) Text('Available: \$${budget.available}'),
            const SizedBox(height: 16),
            TextField(
              controller: maxBidController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your Maximum Bid',
                helperText: 'You\'ll only pay the minimum needed to win',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Proxy bidding: Enter your max bid and we\'ll bid for you automatically.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final maxBid = int.tryParse(maxBidController.text);
              if (maxBid == null || maxBid < minBid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bid must be at least \$${minBid}')),
                );
                return;
              }

              if (budget != null && maxBid > budget.available) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Insufficient budget (available: \$${budget.available})'),
                  ),
                );
                return;
              }

              Navigator.pop(context);

              final authProvider = context.read<AuthProvider>();
              if (authProvider.token == null) return;

              final success = await auctionProvider.placeBid(
                authProvider.token!,
                nomination.id,
                widget.myRosterId,
                maxBid,
                widget.draftId,
              );

              if (mounted) {
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
            },
            child: const Text('Place Bid'),
          ),
        ],
      ),
    );
  }
}
