import 'package:flutter/material.dart';
import '../models/auction_model.dart';

class NominationCard extends StatelessWidget {
  final AuctionNomination nomination;
  final bool isMyBid;
  final VoidCallback onTap;
  final VoidCallback onBid;

  const NominationCard({
    Key? key,
    required this.nomination,
    required this.isMyBid,
    required this.onTap,
    required this.onBid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isMyBid ? 4 : 1,
      color: isMyBid ? Colors.green.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Player name
              Text(
                nomination.playerName ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Position & Team
              Text(
                '${nomination.playerPosition ?? '?'} - ${nomination.playerTeam ?? '?'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              // Current bid
              if (nomination.winningBid != null)
                Text(
                  '\$${nomination.winningBid}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isMyBid ? Colors.green : Colors.black,
                  ),
                )
              else
                const Text(
                  'No bids',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              // Winning indicator
              if (isMyBid)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // Timer
              _buildTimer(nomination.deadline),
              const SizedBox(height: 8),
              // Bid button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onBid,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Bid', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimer(DateTime? deadline) {
    if (deadline == null) return const SizedBox.shrink();

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final remaining = deadline.difference(DateTime.now());

        if (remaining.isNegative) {
          return const Row(
            children: [
              Icon(Icons.timer_off, size: 14, color: Colors.red),
              SizedBox(width: 4),
              Text(
                'Expired',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          );
        }

        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;

        Color timerColor = Colors.orange;
        if (remaining.inHours < 1) {
          timerColor = Colors.red;
        } else if (remaining.inHours < 6) {
          timerColor = Colors.orange;
        } else {
          timerColor = Colors.green;
        }

        return Row(
          children: [
            Icon(Icons.timer, size: 14, color: timerColor),
            const SizedBox(width: 4),
            Text(
              hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
              style: TextStyle(fontSize: 12, color: timerColor),
            ),
          ],
        );
      },
    );
  }
}
