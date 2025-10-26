import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/draft_provider.dart';
import '../models/draft_pick_model.dart';

class DraftBoardWidget extends StatelessWidget {
  const DraftBoardWidget({super.key});

  Color _getPositionColor(String? position) {
    if (position == null) return Colors.grey;
    switch (position) {
      case 'QB':
        return Colors.red.shade400;
      case 'RB':
        return Colors.green.shade400;
      case 'WR':
        return Colors.blue.shade400;
      case 'TE':
        return Colors.orange.shade400;
      case 'K':
        return Colors.purple.shade400;
      case 'DEF':
        return Colors.brown.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

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

        // Group picks by roster and round for easy lookup
        final picksByRosterAndRound = <int, Map<int, DraftPick>>{};
        for (var pick in picks) {
          picksByRosterAndRound.putIfAbsent(pick.rosterId, () => {});
          picksByRosterAndRound[pick.rosterId]![pick.round] = pick;
        }

        return Column(
          children: [
            // Draft Board Grid (Teams on X-axis, Rounds on Y-axis)
            Expanded(
              child: order.isEmpty
                  ? const Center(child: Text('Draft order not set'))
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            Theme.of(context).colorScheme.primaryContainer,
                          ),
                          headingRowHeight: 40,
                          dataRowHeight: 60,
                          columnSpacing: 4,
                          horizontalMargin: 8,
                          columns: [
                            DataColumn(
                              label: Container(
                                width: 60,
                                child: const Text(
                                  'Round',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            ...order.map((team) => DataColumn(
                              label: Container(
                                width: 100,
                                child: Center(
                                  child: Text(
                                    team.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )),
                          ],
                          rows: List.generate(draft.rounds, (roundIndex) {
                            final round = roundIndex + 1;

                            return DataRow(
                              cells: [
                                // Round number cell
                                DataCell(
                                  Container(
                                    width: 60,
                                    child: Center(
                                      child: Text(
                                        'R$round',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Create a cell for each team's pick in this round
                                ...order.map((team) {
                                  final pick = picksByRosterAndRound[team.rosterId]?[round];
                                  final hasPick = pick?.playerId != null;

                                  return DataCell(
                                    Container(
                                      width: 100,
                                      height: 56,
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: hasPick
                                            ? _getPositionColor(pick?.playerPosition)
                                                .withOpacity(0.2)
                                            : Colors.grey.shade200,
                                        border: Border.all(
                                          color: hasPick
                                              ? _getPositionColor(pick?.playerPosition)
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: hasPick
                                          ? Padding(
                                              padding: const EdgeInsets.all(4.0),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: _getPositionColor(
                                                              pick?.playerPosition),
                                                          borderRadius:
                                                              BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          pick?.playerPosition ?? '',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '#${pick?.pickNumber}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    pick?.playerName ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Center(
                                              child: Icon(
                                                Icons.remove,
                                                color: Colors.grey.shade400,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),

            // Recent Picks Section
            Container(
              height: 125,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Picks',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: picks.isEmpty
                        ? const Center(
                            child: Text(
                              'No picks yet - draft will begin soon',
                              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: picks.length > 10 ? 10 : picks.length,
                            itemBuilder: (context, index) {
                              final pick = picks[picks.length - 1 - index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                elevation: 2,
                                child: Container(
                                  width: 180,
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: _getPositionColor(
                                            pick.playerPosition),
                                        radius: 22,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '#${pick.pickNumber}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              pick.playerPosition ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              pick.playerName ?? 'Unknown',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              pick.pickedByUsername ??
                                                  (pick.rosterNumber != null
                                                      ? 'Team ${pick.rosterNumber}'
                                                      : 'Unknown Team'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
