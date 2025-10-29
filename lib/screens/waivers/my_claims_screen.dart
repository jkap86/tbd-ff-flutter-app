import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/waiver_provider.dart';
import '../../models/waiver_claim.dart';
import '../../models/player_model.dart';
import '../../models/roster_model.dart';
import '../../config/api_config.dart';

class MyClaimsScreen extends StatefulWidget {
  final Roster userRoster;

  const MyClaimsScreen({
    super.key,
    required this.userRoster,
  });

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  Map<int, Player?> _playerCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final waiverProvider = Provider.of<WaiverProvider>(context, listen: false);
    final token = authProvider.token;

    if (token != null) {
      await waiverProvider.loadClaims(
        token: token,
        rosterId: widget.userRoster.rosterId,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<Player?> _getPlayer(int playerId) async {
    if (_playerCache.containsKey(playerId)) {
      return _playerCache[playerId];
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/players/$playerId'),
        headers: ApiConfig.getAuthHeaders(token),
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

  Future<void> _cancelClaim(WaiverClaim claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Claim'),
        content: const Text('Are you sure you want to cancel this waiver claim?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final waiverProvider = Provider.of<WaiverProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) return;

    final success = await waiverProvider.cancelClaim(
      token: token,
      claimId: claim.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Claim cancelled successfully' : 'Failed to cancel claim',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Waiver Claims'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClaims,
          ),
        ],
      ),
      body: Consumer<WaiverProvider>(
        builder: (context, waiverProvider, child) {
          if (_isLoading || waiverProvider.status == WaiverStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final claims = waiverProvider.myClaims;

          if (claims.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending claims',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your waiver claims will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadClaims,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: claims.length,
              itemBuilder: (context, index) {
                final claim = claims[index];
                return FutureBuilder<Player?>(
                  future: _getPlayer(claim.playerId),
                  builder: (context, addSnapshot) {
                    return FutureBuilder<Player?>(
                      future: claim.dropPlayerId != null
                          ? _getPlayer(claim.dropPlayerId!)
                          : Future.value(null),
                      builder: (context, dropSnapshot) {
                        final addPlayer = addSnapshot.data;
                        final dropPlayer = dropSnapshot.data;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with status
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(claim.status)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        claim.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(claim.status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Bid: \$${claim.bidAmount}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Add player
                                Row(
                                  children: [
                                    const Icon(Icons.add_circle, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        addPlayer?.fullName ?? 'Loading...',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (addPlayer != null)
                                      Text(
                                        addPlayer.positionTeam,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),

                                // Drop player
                                if (claim.dropPlayerId != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.remove_circle, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dropPlayer?.fullName ?? 'Loading...',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      if (dropPlayer != null)
                                        Text(
                                          dropPlayer.positionTeam,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],

                                // Failure reason
                                if (claim.isFailed && claim.failureReason != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error, color: Colors.red, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            claim.failureReason!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Cancel button for pending claims
                                if (claim.isPending) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _cancelClaim(claim),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Cancel Claim'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],

                                // Timestamp
                                const SizedBox(height: 8),
                                Text(
                                  'Submitted: ${_formatDate(claim.createdAt)}',
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
                  },
                );
              },
            ),
          );
        },
      ),
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
