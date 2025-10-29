import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/transaction.dart';
import '../../models/player_model.dart';
import '../../config/api_config.dart';

class TransactionList extends StatefulWidget {
  final List<Transaction> transactions;
  final String? token;

  const TransactionList({
    super.key,
    required this.transactions,
    this.token,
  });

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  Map<int, Player?> _playerCache = {};

  Future<Player?> _getPlayer(int playerId) async {
    if (_playerCache.containsKey(playerId)) {
      return _playerCache[playerId];
    }

    try {
      if (widget.token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/players/$playerId'),
        headers: ApiConfig.getAuthHeaders(widget.token!),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final player = Player.fromJson(data['data']);
        _playerCache[playerId] = player;
        return player;
      }
    } catch (e) {
      debugPrint('Error fetching player: $e');
    }

    return null;
  }

  Color _getTypeColor(Transaction transaction) {
    if (transaction.isWaiver) {
      return Colors.orange;
    } else if (transaction.isFreeAgent) {
      return Colors.green;
    }
    return Colors.grey;
  }

  IconData _getTypeIcon(Transaction transaction) {
    if (transaction.isWaiver) {
      return Icons.access_time;
    } else if (transaction.isFreeAgent) {
      return Icons.check_circle;
    }
    return Icons.swap_horiz;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.transactions.length,
      itemBuilder: (context, index) {
        final transaction = widget.transactions[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Type badge
                    Row(
                      children: [
                        Icon(
                          _getTypeIcon(transaction),
                          color: _getTypeColor(transaction),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(transaction).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            transaction.typeDisplay,
                            style: TextStyle(
                              color: _getTypeColor(transaction),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Waiver bid amount
                    if (transaction.waiverBid != null)
                      Text(
                        '\$${transaction.waiverBid}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Team name
                if (transaction.username != null) ...[
                  Text(
                    transaction.username!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Added players
                if (transaction.adds.isNotEmpty) ...[
                  ...transaction.adds.map((playerId) {
                    return FutureBuilder<Player?>(
                      future: _getPlayer(playerId),
                      builder: (context, snapshot) {
                        final player = snapshot.data;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  player?.fullName ?? 'Loading...',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              if (player != null)
                                Text(
                                  player.positionTeam,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ],

                // Dropped players
                if (transaction.drops.isNotEmpty) ...[
                  ...transaction.drops.map((playerId) {
                    return FutureBuilder<Player?>(
                      future: _getPlayer(playerId),
                      builder: (context, snapshot) {
                        final player = snapshot.data;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_circle,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  player?.fullName ?? 'Loading...',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              if (player != null)
                                Text(
                                  player.positionTeam,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ],

                // Timestamp
                const SizedBox(height: 8),
                Text(
                  _formatDate(transaction.processedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
