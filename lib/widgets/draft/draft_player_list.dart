import 'package:flutter/material.dart';
import '../../models/player_model.dart';
import '../../providers/draft_provider.dart';
import '../../providers/auth_provider.dart';

/// A widget that displays the list of available players in the draft.
/// Shows players with their stats and allows adding to queue or drafting.
class DraftPlayerList extends StatelessWidget {
  final List<Player> filteredPlayers;
  final Player? selectedPlayer;
  final List<Player> draftQueue;
  final DraftProvider draftProvider;
  final AuthProvider authProvider;
  final Function(Player) onPlayerCardTap;
  final bool isSorting;

  const DraftPlayerList({
    super.key,
    required this.filteredPlayers,
    required this.selectedPlayer,
    required this.draftQueue,
    required this.draftProvider,
    required this.authProvider,
    required this.onPlayerCardTap,
    this.isSorting = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredPlayers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No players available'),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPlayers.length,
          itemBuilder: (context, index) {
            final player = filteredPlayers[index];
            final isSelected = selectedPlayer?.id == player.id;
            final isInQueue = draftQueue.any((p) => p.id == player.id);

            return InkWell(
              onTap: () => onPlayerCardTap(player),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: _buildPlayerCardContent(
                  context,
                  player,
                  isSelected,
                  isInQueue,
                ),
              ),
            );
          },
        ),
        // Show loading overlay while sorting
        if (isSorting)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Sorting players...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerCardContent(
    BuildContext context,
    Player player,
    bool isSelected,
    bool isInQueue,
  ) {
    // This is a simplified version - the parent widget should pass
    // the actual player card widget with stats
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPositionColor(player.position),
          child: Text(
            player.position,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          player.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(player.team ?? ''),
        trailing: isInQueue
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Q${draftQueue.indexWhere((p) => p.id == player.id) + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case 'QB':
        return Colors.red.shade400;
      case 'RB':
        return Colors.green.shade400;
      case 'WR':
        return Colors.blue.shade400;
      case 'TE':
        return Colors.orange.shade400;
      case 'FLEX':
      case 'SUPER_FLEX':
      case 'WRT':
      case 'REC_FLEX':
        return Colors.teal.shade400;
      case 'K':
        return Colors.purple.shade400;
      case 'DEF':
        return Colors.brown.shade400;
      case 'DL':
        return Colors.indigo.shade400;
      case 'LB':
        return Colors.cyan.shade400;
      case 'DB':
        return Colors.pink.shade400;
      case 'IDP_FLEX':
        return Colors.deepPurple.shade400;
      case 'ALL':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade400;
    }
  }
}
