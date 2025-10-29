import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/draft_provider.dart';
import '../models/draft_order_model.dart';

class ChessTimerTeamListWidget extends StatelessWidget {
  const ChessTimerTeamListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DraftProvider>(
      builder: (context, draftProvider, _) {
        final draft = draftProvider.currentDraft;
        final draftOrder = draftProvider.draftOrder;

        if (draft == null || draftOrder.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No draft order available'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: draftOrder.length,
          itemBuilder: (context, index) {
            final order = draftOrder[index];
            final isCurrentPick = order.rosterId == draft.currentRosterId;
            final timeRemaining = draftProvider.getRosterTimeRemaining(order.rosterId);

            return _buildTeamCard(
              context: context,
              order: order,
              timeRemaining: timeRemaining,
              isCurrentPick: isCurrentPick,
            );
          },
        );
      },
    );
  }

  Widget _buildTeamCard({
    required BuildContext context,
    required DraftOrder order,
    required int? timeRemaining,
    required bool isCurrentPick,
  }) {
    final isLow = timeRemaining != null && timeRemaining < 300; // < 5 minutes
    final isCritical = timeRemaining != null && timeRemaining < 60; // < 1 minute

    Color timeColor = isCritical
        ? Colors.red
        : (isLow ? Colors.orange : Theme.of(context).colorScheme.primary);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentPick ? 4 : 1,
      color: isCurrentPick
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Position number
            CircleAvatar(
              backgroundColor: isCurrentPick
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                '${order.draftPosition}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrentPick ? Colors.white : null,
                ),
              ),
            ),
            if (isCurrentPick) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.play_arrow,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ],
          ],
        ),
        title: Text(
          order.displayName,
          style: TextStyle(
            fontWeight: isCurrentPick ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Team ${order.rosterNumber}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: timeRemaining != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_bottom,
                        color: timeColor,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(timeRemaining),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: timeColor,
                        ),
                      ),
                    ],
                  ),
                  if (isCritical)
                    Text(
                      'CRITICAL!',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: timeColor,
                      ),
                    )
                  else if (isLow)
                    Text(
                      'Low Time',
                      style: TextStyle(
                        fontSize: 10,
                        color: timeColor,
                      ),
                    ),
                ],
              )
            : const Icon(Icons.timer_off, color: Colors.grey),
      ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }
}
