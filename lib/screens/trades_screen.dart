import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trade_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/trade_model.dart';
import '../widgets/league_chat_tab_widget.dart';
import '../widgets/common/empty_state_widget.dart';
import '../services/socket_service.dart';
import 'propose_trade_screen.dart';

class TradesScreen extends StatefulWidget {
  final int leagueId;

  const TradesScreen({super.key, required this.leagueId});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen> {
  final SocketService _socketService = SocketService();
  double _chatDrawerHeight = 0.1; // Start collapsed showing preview

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tradeProvider = Provider.of<TradeProvider>(context, listen: false);
      tradeProvider.loadLeagueTrades(widget.leagueId);
      _setupSocketListeners();
    });
  }

  void _setupSocketListeners() {
    final tradeProvider = Provider.of<TradeProvider>(context, listen: false);

    // Set up trade event listeners
    _socketService.onTradeProposed = (data) {
      tradeProvider.onTradeProposed(data);
    };

    _socketService.onTradeProcessed = (data) {
      tradeProvider.onTradeProcessed(data);
    };

    _socketService.onTradeRejected = (data) {
      tradeProvider.onTradeRejected(data);
    };

    _socketService.onTradeCancelled = (data) {
      tradeProvider.onTradeCancelled(data);
    };
  }

  @override
  void dispose() {
    _socketService.clearCallbacks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tradeProvider = Provider.of<TradeProvider>(context);
    final leagueProvider = Provider.of<LeagueProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final myRoster = leagueProvider.selectedLeagueRosters.firstWhere(
      (r) => r.userId == authProvider.user?.id,
      orElse: () => leagueProvider.selectedLeagueRosters.first,
    );

    final myRosterId = myRoster.id;

    final pendingTrades = tradeProvider.getPendingTrades(myRosterId);
    final completedTrades = tradeProvider.completedTrades;

    final drawerHeight = MediaQuery.of(context).size.height * _chatDrawerHeight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trades'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProposeTradeScreen(
                leagueId: widget.leagueId,
                myRosterId: myRosterId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Propose Trade'),
      ),
      body: Stack(
        children: [
          // Main content
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: drawerHeight,
            child: tradeProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'Pending'),
                            Tab(text: 'History'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Pending trades
                              pendingTrades.isEmpty
                                  ? EmptyStateWidget(
                                      icon: Icons.swap_horiz,
                                      title: 'No pending trades',
                                      subtitle: 'Propose a trade to get started',
                                      actionLabel: 'Propose Trade',
                                      onAction: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProposeTradeScreen(
                                              leagueId: widget.leagueId,
                                              myRosterId: myRosterId,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : ListView.builder(
                                      itemCount: pendingTrades.length,
                                      itemBuilder: (context, index) {
                                        final trade = pendingTrades[index];
                                        return _TradeCard(
                                          trade: trade,
                                          myRosterId: myRosterId,
                                        );
                                      },
                                    ),
                              // Completed trades
                              completedTrades.isEmpty
                                  ? const EmptyStateWidget(
                                      icon: Icons.history,
                                      title: 'No trade history',
                                      subtitle: 'Completed trades will appear here',
                                    )
                                  : ListView.builder(
                                      itemCount: completedTrades.length,
                                      itemBuilder: (context, index) {
                                        final trade = completedTrades[index];
                                        return _TradeCard(
                                          trade: trade,
                                          myRosterId: myRosterId,
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                      ],
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
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar and header
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _chatDrawerHeight = _chatDrawerHeight <= 0.2 ? 0.5 : 0.1;
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            // Handle bar
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Title
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'League Chat',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Chat content
                    if (_chatDrawerHeight > 0.2)
                      Expanded(
                        child: LeagueChatTabWidget(leagueId: widget.leagueId),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  final Trade trade;
  final int myRosterId;

  const _TradeCard({
    required this.trade,
    required this.myRosterId,
  });

  @override
  Widget build(BuildContext context) {
    final tradeProvider = Provider.of<TradeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final iAmProposer = trade.proposerRosterId == myRosterId;
    final iAmReceiver = trade.receiverRosterId == myRosterId;

    final proposerItems = trade.items
            ?.where((item) => item.fromRosterId == trade.proposerRosterId)
            .toList() ??
        [];
    final receiverItems = trade.items
            ?.where((item) => item.fromRosterId == trade.receiverRosterId)
            .toList() ??
        [];

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        leading: _getStatusIcon(trade.status),
        title: Text(
          iAmProposer
              ? 'To: ${trade.receiverTeamName ?? "Unknown"}'
              : 'From: ${trade.proposerTeamName ?? "Unknown"}',
        ),
        subtitle: Text(_getStatusText(trade.status)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proposer gives
                Text(
                  '${trade.proposerTeamName} gives:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...proposerItems.map((item) => Text('• ${item.playerName}')),
                const SizedBox(height: 12),

                // Receiver gives
                Text(
                  '${trade.receiverTeamName} gives:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...receiverItems.map((item) => Text('• ${item.playerName}')),
                const SizedBox(height: 16),

                // Actions
                if (trade.isPending && iAmReceiver) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final success = await tradeProvider.acceptTrade(
                              token: authProvider.token!,
                              tradeId: trade.id,
                              rosterId: myRosterId,
                            );

                            if (context.mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Trade accepted!')),
                              );
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Accept'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final success = await tradeProvider.rejectTrade(
                              token: authProvider.token!,
                              tradeId: trade.id,
                              rosterId: myRosterId,
                            );

                            if (context.mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Trade rejected')),
                              );
                            }
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (trade.isPending && iAmProposer) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      final success = await tradeProvider.cancelTrade(
                        token: authProvider.token!,
                        tradeId: trade.id,
                        rosterId: myRosterId,
                      );

                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Trade cancelled')),
                        );
                      }
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
      case 'accepted':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'rejected':
        return const Icon(Icons.cancel, color: Colors.red);
      case 'cancelled':
        return const Icon(Icons.block, color: Colors.grey);
      default:
        return const Icon(Icons.help);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
