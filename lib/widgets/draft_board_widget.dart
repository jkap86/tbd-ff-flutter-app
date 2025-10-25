import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/draft_provider.dart';
import '../models/draft_pick_model.dart';

class DraftBoardWidget extends StatelessWidget {
  const DraftBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DraftProvider>(
      builder: (context, draftProvider, child) {
        final draft = draftProvider.currentDraft;
        final picks = draftProvider.draftPicks;
        final order = draftProvider.draftOrder;

        if (draft == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Group picks by round
        final picksByRound = <int, List<DraftPick>>{};
        for (var pick in picks) {
          picksByRound.putIfAbsent(pick.round, () => []).add(pick);
        }

        return Column(
          children: [
            // Header with round numbers
            Container(
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Row(
                children: [
                  const SizedBox(width: 60), // Space for team names
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          draft.rounds,
                          (index) => SizedBox(
                            width: 80,
                            child: Center(
                              child: Text(
                                'R${index + 1}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Draft board grid
            Expanded(
              child: order.isEmpty
                  ? const Center(child: Text('Draft order not set'))
                  : ListView.builder(
                      itemCount: order.length,
                      itemBuilder: (context, teamIndex) {
                        final team = order[teamIndex];

                        return Row(
                          children: [
                            // Team name/number
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                              child: Center(
                                child: Text(
                                  team.displayName,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Pick slots for each round
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: List.generate(
                                    draft.rounds,
                                    (roundIndex) {
                                      final round = roundIndex + 1;

                                      // Find pick for this team in this round
                                      final roundPicks =
                                          picksByRound[round] ?? [];
                                      final pick = roundPicks.firstWhere(
                                        (p) => p.rosterId == team.rosterId,
                                        orElse: () => DraftPick(
                                          id: 0,
                                          draftId: 0,
                                          pickNumber: 0,
                                          round: round,
                                          pickInRound: 0,
                                          rosterId: team.rosterId,
                                          isAutoPick: false,
                                          pickedAt: DateTime.now(),
                                          createdAt: DateTime.now(),
                                        ),
                                      );

                                      final hasPick = pick.playerId != null;

                                      return Container(
                                        width: 80,
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: hasPick
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Tooltip(
                                          message: hasPick
                                              ? pick.playerDisplay
                                              : 'Not picked yet',
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (hasPick) ...[
                                                  Text(
                                                    pick.playerName ?? '',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                  Text(
                                                    pick.playerPosition ?? '',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .secondary,
                                                        ),
                                                  ),
                                                ] else ...[
                                                  const SizedBox(height: 20),
                                                  Icon(
                                                    Icons.more_horiz,
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Recent Picks
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Recent Picks',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Expanded(
                    child: picks.isEmpty
                        ? const Center(child: Text('No picks yet'))
                        : ListView.builder(
                            reverse: true,
                            itemCount: picks.length > 5 ? 5 : picks.length,
                            itemBuilder: (context, index) {
                              final pick =
                                  picks[picks.length - 1 - index];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  child: Text(
                                    pick.pickNumber.toString(),
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                                title: Text(
                                  pick.playerName ?? 'Unknown',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                subtitle: Text(
                                  '${pick.playerPosition} - ${pick.pickedByUsername ?? "Team ${pick.rosterNumber}"}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
