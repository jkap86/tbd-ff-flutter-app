import 'package:flutter/material.dart';
import '../../models/draft_pick_model.dart';

class DraftPicksListWidget extends StatelessWidget {
  final List<DraftPick> picks;

  const DraftPicksListWidget({
    super.key,
    required this.picks,
  });

  @override
  Widget build(BuildContext context) {
    // Sort picks by pick number descending (most recent first)
    final sortedPicks = List<DraftPick>.from(picks)
      ..sort((a, b) => b.pickNumber.compareTo(a.pickNumber));

    if (sortedPicks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_football,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No picks yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Picks will appear here as they are made',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: sortedPicks.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final pick = sortedPicks[index];
        final isRecent = index < 3; // Highlight the 3 most recent picks

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          elevation: isRecent ? 4 : 1,
          color: isRecent
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPositionColor(pick.playerPosition),
              child: Text(
                pick.playerPosition ?? '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    pick.playerName ?? 'Unknown Player',
                    style: TextStyle(
                      fontWeight: isRecent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (pick.playerTeam != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pick.playerTeam!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              'Pick #${pick.pickNumber} • Round ${pick.round}, Pick ${pick.pickInRound} • ${pick.pickedByUsername}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isRecent
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Color _getPositionColor(String? position) {
    switch (position?.toUpperCase()) {
      case 'QB':
        return Colors.red.shade700;
      case 'RB':
        return Colors.green.shade700;
      case 'WR':
        return Colors.blue.shade700;
      case 'TE':
        return Colors.orange.shade700;
      case 'K':
        return Colors.purple.shade700;
      case 'DEF':
        return Colors.brown.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
