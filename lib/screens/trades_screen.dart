import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trade_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/trade_model.dart';
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
      body: tradeProvider.isLoading
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
                            ? const Center(
                                child: Text('No pending trades'),
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
                            ? const Center(
                                child: Text('No trade history'),
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
