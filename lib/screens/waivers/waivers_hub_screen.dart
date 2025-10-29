import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/waiver_provider.dart';
import '../../models/roster_model.dart';
import '../../widgets/transaction/transaction_list.dart';
import '../../widgets/league_chat_tab_widget.dart';
import 'my_claims_screen.dart';
import '../players/available_players_screen.dart';

class WaiversHubScreen extends StatefulWidget {
  final int leagueId;
  final Roster userRoster;

  const WaiversHubScreen({
    super.key,
    required this.leagueId,
    required this.userRoster,
  });

  @override
  State<WaiversHubScreen> createState() => _WaiversHubScreenState();
}

class _WaiversHubScreenState extends State<WaiversHubScreen> {
  double _chatDrawerHeight = 0.1; // Start collapsed showing preview

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final waiverProvider = Provider.of<WaiverProvider>(context, listen: false);
    final token = authProvider.token;

    if (token != null) {
      await Future.wait([
        waiverProvider.loadClaims(
          token: token,
          rosterId: widget.userRoster.rosterId,
        ),
        waiverProvider.loadTransactions(
          token: token,
          leagueId: widget.leagueId,
        ),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final faabBudget = widget.userRoster.settings?['faab_budget'] ?? 100;

    final drawerHeight = MediaQuery.of(context).size.height * _chatDrawerHeight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waivers & Free Agents'),
      ),
      body: Stack(
        children: [
          // Main content
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: drawerHeight,
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FAAB Budget Card
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FAAB Budget',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$$faabBudget',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      Consumer<WaiverProvider>(
                        builder: (context, waiverProvider, child) {
                          final pendingCount = waiverProvider.pendingClaimsCount;
                          if (pendingCount > 0) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AvailablePlayersScreen(
                              leagueId: widget.leagueId,
                              userRoster: widget.userRoster,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Browse Players'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MyClaimsScreen(
                              userRoster: widget.userRoster,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('My Claims'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Recent Transactions Section
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Consumer<WaiverProvider>(
                builder: (context, waiverProvider, child) {
                  if (waiverProvider.status == WaiverStatus.loading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return TransactionList(
                    transactions: waiverProvider.transactions.take(10).toList(),
                    token: authProvider.token,
                  );
                },
              ),
            ],
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
