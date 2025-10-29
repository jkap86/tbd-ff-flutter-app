import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auction_model.dart';
import '../models/player_model.dart';
import '../providers/auction_provider.dart';
import '../providers/auth_provider.dart';

class AuctionDraftScreen extends StatefulWidget {
  final int draftId;
  final int myRosterId;
  final String draftName;

  const AuctionDraftScreen({
    super.key,
    required this.draftId,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAuctionData();
    _setupTimer();
  }

  void _loadAuctionData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final auctionProvider =
        Provider.of<AuctionProvider>(context, listen: false);

    // Setup socket listeners
    auctionProvider.setupSlowAuctionListeners(widget.draftId, widget.myRosterId);

    // Load initial data
    auctionProvider.loadAuctionData(
      token: authProvider.token!,
      draftId: widget.draftId,
      myRosterId: widget.myRosterId,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Consumer<AuctionProvider>(
            builder: (context, auctionProvider, _) {
              final budget = auctionProvider.myBudget;
              if (budget == null) {
                return const SizedBox(height: 80);
              }
              return BudgetDisplayWidget(budget: budget);
            },
          ),
        ),
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
                  const SizedBox(height: 16),
                  Text(
                    auctionProvider.errorMessage ?? 'An error occurred',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
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

          return Column(
            children: [
              // Current nomination area
              if (currentNomination != null)
                Expanded(
                  flex: 3,
                  child: CurrentNominationWidget(
                    nomination: currentNomination,
                    bidHistory: auctionProvider.getBidsForNomination(
                      currentNomination.id,
                    ),
                    onPlaceBid: (maxBid) => _placeBid(maxBid, currentNomination.id),
                    isMyBid: auctionProvider.isMyBid(currentNomination),
                  ),
                )
              else
                const Expanded(
                  flex: 3,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gavel, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No active nominations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Waiting for a player to be nominated...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom tabs
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Available Players'),
                    Tab(text: 'My Roster'),
                    Tab(text: 'Bid History'),
                    Tab(text: 'Activity'),
                  ],
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                ),
              ),

              // Bottom drawer content
              Expanded(
                flex: 2,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvailablePlayersTab(auctionProvider),
                    _buildMyRosterTab(),
                    _buildBidHistoryTab(auctionProvider, currentNomination),
                    _buildActivityTab(auctionProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvailablePlayersTab(AuctionProvider auctionProvider) {
    final filteredPlayers = _filterPlayers(auctionProvider.availablePlayers);

    return Column(
      children: [
        // Search and filter
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search players...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
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
                    return ListTile(
                      title: Text(player.displayName),
                      subtitle: Text(player.positionTeam),
                      trailing: ElevatedButton(
                        onPressed: () => _nominatePlayer(player),
                        child: const Text('Nominate'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMyRosterTab() {
    return const Center(
      child: Text('My Roster - Coming Soon'),
    );
  }

  Widget _buildBidHistoryTab(
    AuctionProvider auctionProvider,
    AuctionNomination? currentNomination,
  ) {
    if (currentNomination == null) {
      return const Center(
        child: Text('No active nomination to show bids for'),
      );
    }

    final bids = auctionProvider.getBidsForNomination(currentNomination.id);
    return BidHistoryWidget(bids: bids);
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
      player.id,
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

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBudgetItem(
            context,
            'Budget',
            '\$${budget.startingBudget}',
            Colors.grey,
          ),
          _buildBudgetItem(
            context,
            'Spent',
            '\$${budget.spent}',
            Colors.red,
          ),
          if (showReserved)
            _buildBudgetItem(
              context,
              'Reserved',
              '\$${budget.reserved}',
              Colors.orange,
            ),
          _buildBudgetItem(
            context,
            'Available',
            '\$${budget.available}',
            Colors.green,
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
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 24 : 20,
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
  int? _selectedQuickBid;

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentBid = widget.nomination.winningBid ?? 0;
    final timeRemaining = widget.nomination.timeRemaining;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Player card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      widget.nomination.playerName ?? 'Unknown Player',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.nomination.playerPositionTeam,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Current bid info
            Card(
              color: widget.isMyBid ? Colors.green.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                                fontSize: 14,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Time Remaining',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatDuration(timeRemaining),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: timeRemaining.inSeconds < 30
                                    ? Colors.red
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (widget.nomination.winningTeamName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Winning Team: ${widget.nomination.winningTeamName}',
                        style: TextStyle(
                          color: widget.isMyBid ? Colors.green : Colors.grey.shade700,
                          fontWeight: widget.isMyBid ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bidding controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Quick Bids',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickBidButton(currentBid + 1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickBidButton(currentBid + 5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickBidButton(currentBid + 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Or enter max bid (proxy bid)',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bidController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter max bid',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                        helperText: 'You\'ll pay the minimum needed to win',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedQuickBid = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _placeBid,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: const Text(
                        'Place Bid',
                        style: TextStyle(
                          fontSize: 18,
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
  }

  Widget _buildQuickBidButton(int amount) {
    final isSelected = _selectedQuickBid == amount;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedQuickBid = amount;
          _bidController.clear();
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
        foregroundColor: isSelected ? Colors.white : null,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        '\$$amount',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _placeBid() {
    int? maxBid;

    if (_selectedQuickBid != null) {
      maxBid = _selectedQuickBid;
    } else if (_bidController.text.isNotEmpty) {
      maxBid = int.tryParse(_bidController.text);
    }

    if (maxBid == null || maxBid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid bid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentBid = widget.nomination.winningBid ?? 0;
    if (maxBid <= currentBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bid must be greater than current bid (\$$currentBid)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onPlaceBid(maxBid);

    // Clear inputs
    setState(() {
      _selectedQuickBid = null;
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'WINNING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
