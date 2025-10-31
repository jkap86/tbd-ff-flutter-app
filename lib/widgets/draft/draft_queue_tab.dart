import 'package:flutter/material.dart';
import '../../models/player_model.dart';
import '../../providers/draft_provider.dart';
import '../../providers/auth_provider.dart';

/// A widget that displays the draft queue tab.
/// Allows users to manage their queue of players to draft.
class DraftQueueTab extends StatelessWidget {
  final List<Player> draftQueue;
  final DraftProvider draftProvider;
  final AuthProvider authProvider;
  final Function() onClearQueue;
  final Function(int oldIndex, int newIndex) onReorder;
  final Function(int index) onRemoveFromQueue;
  final Widget bottomPickButton;

  const DraftQueueTab({
    super.key,
    required this.draftQueue,
    required this.draftProvider,
    required this.authProvider,
    required this.onClearQueue,
    required this.onReorder,
    required this.onRemoveFromQueue,
    required this.bottomPickButton,
  });

  @override
  Widget build(BuildContext context) {
    if (draftQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.playlist_add,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Queue is Empty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add players from the Available Players tab',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Queue header with clear button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Players will be drafted in order when autodraft is on',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (draftQueue.isNotEmpty)
                TextButton.icon(
                  onPressed: onClearQueue,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Queue list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: draftQueue.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final player = draftQueue[index];
              return Card(
                key: ValueKey(player.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Queue position number
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Position avatar
                      CircleAvatar(
                        backgroundColor: _getPositionColor(player.position),
                        radius: 18,
                        child: Text(
                          player.position,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    player.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${player.team} - ${player.position}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Icon(Icons.drag_handle, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      // Remove button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () => onRemoveFromQueue(index),
                        tooltip: 'Remove from Queue',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom pick button for queue
        bottomPickButton,
      ],
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
