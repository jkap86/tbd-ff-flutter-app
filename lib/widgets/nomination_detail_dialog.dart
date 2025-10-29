import 'package:flutter/material.dart';
import '../models/auction_model.dart';

class NominationDetailDialog extends StatelessWidget {
  final AuctionNomination nomination;
  final List<AuctionBid> bidHistory;
  final Function(int maxBid) onPlaceBid;
  final int? myRosterId;
  final int? availableBudget;

  const NominationDetailDialog({
    Key? key,
    required this.nomination,
    required this.bidHistory,
    required this.onPlaceBid,
    required this.myRosterId,
    this.availableBudget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          children: [
            // Player header
            _buildPlayerHeader(),
            const Divider(height: 1),
            // Current bid info
            _buildCurrentBidInfo(),
            const Divider(height: 1),
            // Bid history (scrollable)
            Expanded(
              child: _buildBidHistory(),
            ),
            const Divider(height: 1),
            // Bid controls
            _buildBidControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nomination.playerName ?? 'Unknown Player',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(navigatorKey.currentContext!).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${nomination.playerPosition ?? '?'} - ${nomination.playerTeam ?? '?'}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBidInfo() {
    final isMyBid = myRosterId != null && nomination.winningRosterId == myRosterId;
    final timeRemaining = nomination.timeRemaining;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Bid',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              if (nomination.winningBid != null)
                Text(
                  '\$${nomination.winningBid}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isMyBid ? Colors.green : Colors.black,
                  ),
                )
              else
                const Text(
                  'No bids',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          if (nomination.winningTeamName != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Leading Team:', style: TextStyle(color: Colors.grey)),
                Row(
                  children: [
                    Text(
                      nomination.winningTeamName!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (isMyBid) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Time Remaining:', style: TextStyle(color: Colors.grey)),
              _buildTimeRemaining(timeRemaining),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRemaining(Duration timeRemaining) {
    Color timerColor = Colors.orange;
    if (timeRemaining.inHours < 1) {
      timerColor = Colors.red;
    } else if (timeRemaining.inHours < 6) {
      timerColor = Colors.orange;
    } else {
      timerColor = Colors.green;
    }

    final hours = timeRemaining.inHours;
    final minutes = timeRemaining.inMinutes % 60;
    final timeString = hours > 0 ? '$hours hours $minutes min' : '$minutes min';

    return Row(
      children: [
        Icon(Icons.timer, size: 16, color: timerColor),
        const SizedBox(width: 4),
        Text(
          timeString,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: timerColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBidHistory() {
    if (bidHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No bids yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Sort bids by amount (highest first)
    final sortedBids = List<AuctionBid>.from(bidHistory)
      ..sort((a, b) => b.bidAmount.compareTo(a.bidAmount));

    return ListView.builder(
      itemCount: sortedBids.length,
      itemBuilder: (context, index) {
        final bid = sortedBids[index];
        final isMyBid = myRosterId != null && bid.rosterId == myRosterId;

        return ListTile(
          leading: bid.isWinning
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.circle_outlined, color: Colors.grey),
          title: Row(
            children: [
              Text(
                '\$${bid.bidAmount}',
                style: TextStyle(
                  fontWeight: bid.isWinning ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
              if (isMyBid) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${bid.teamName ?? 'Unknown Team'} • ${_timeAgo(bid.createdAt)}',
          ),
          trailing: Text(
            'Max: \$${bid.maxBid}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildBidControls(BuildContext context) {
    final currentBid = nomination.winningBid ?? 0;
    final minBid = currentBid + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availableBudget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Available Budget: \$${availableBudget}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showBidDialog(context, minBid);
                  },
                  icon: const Icon(Icons.add),
                  label: Text('Place Bid (min \$${minBid})'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBidDialog(BuildContext context, int minBid) {
    final TextEditingController maxBidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bid on ${nomination.playerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current bid: \$${nomination.winningBid ?? 0}'),
            Text('Minimum bid: \$${minBid}'),
            if (availableBudget != null)
              Text('Available: \$${availableBudget}'),
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
              'Proxy bidding: Enter your max bid and we\'ll bid for you automatically up to that amount.',
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
            onPressed: () {
              final maxBid = int.tryParse(maxBidController.text);
              if (maxBid == null || maxBid < minBid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bid must be at least \$${minBid}')),
                );
                return;
              }

              if (availableBudget != null && maxBid > availableBudget!) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Insufficient budget (available: \$${availableBudget})')),
                );
                return;
              }

              Navigator.pop(context);
              onPlaceBid(maxBid);
            },
            child: const Text('Place Bid'),
          ),
        ],
      ),
    );
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
}

// Global navigator key for dialog navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
