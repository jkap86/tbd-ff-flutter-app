import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/draft_provider.dart';
import '../providers/league_provider.dart';
import '../models/draft_pick_model.dart';

class DraftBoardWidget extends StatefulWidget {
  const DraftBoardWidget({super.key});

  @override
  State<DraftBoardWidget> createState() => _DraftBoardWidgetState();
}

class _DraftBoardWidgetState extends State<DraftBoardWidget> {
  bool _showByRosterPosition = false; // false = by round, true = by roster position

  List<String> _expandRosterPositions(List<dynamic> rosterPositions) {
    // Expand roster positions that have counts
    // e.g., {position: "RB", count: 2} becomes ["RB1", "RB2"]
    final expanded = <String>[];

    for (var pos in rosterPositions) {
      if (pos is Map<String, dynamic>) {
        final position = pos['position']?.toString() ?? '';
        final count = pos['count'] as int? ?? 1;

        if (count > 1) {
          for (var i = 1; i <= count; i++) {
            expanded.add('$position$i');
          }
        } else {
          expanded.add(position);
        }
      } else if (pos is String) {
        expanded.add(pos);
      } else {
        expanded.add(pos.toString());
      }
    }

    return expanded;
  }

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
            // Toggle button for Y-axis view
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Round'),
                    selected: !_showByRosterPosition,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _showByRosterPosition = false);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Roster Position'),
                    selected: _showByRosterPosition,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _showByRosterPosition = true);
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Draft Board Grid (Teams on X-axis, Rounds/Position on Y-axis)
            Expanded(
              child: order.isEmpty
                  ? const Center(child: Text('Draft order not set'))
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _showByRosterPosition
                            ? _buildByRosterPositionView(context, draftProvider, order, picks)
                            : _buildByRoundView(context, draft, order, picksByRosterAndRound),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildByRoundView(
    BuildContext context,
    dynamic draft,
    List<dynamic> order,
    Map<int, Map<int, DraftPick>> picksByRosterAndRound,
  ) {
    return DataTable(
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      team.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: team.isAutodrafting
                            ? Colors.amber.shade700
                            : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (team.isAutodrafting) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.auto_mode,
                      size: 12,
                      color: Colors.amber.shade700,
                    ),
                  ],
                ],
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
    );
  }

  Widget _buildByRosterPositionView(
    BuildContext context,
    DraftProvider draftProvider,
    List<dynamic> order,
    List<DraftPick> picks,
  ) {
    // Get league's roster positions from provider
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
    final league = leagueProvider.selectedLeague;
    final rosterPositions = league?.rosterPositions ?? [];

    if (rosterPositions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No roster positions defined for this league'),
        ),
      );
    }

    // Group picks by roster ID and assign slots based on draft order
    final picksByRosterAndSlot = <int, Map<int, DraftPick>>{};
    final picksByRoster = <int, List<DraftPick>>{};

    // First, group all picks by roster
    for (var pick in picks) {
      if (pick.playerId != null) {
        picksByRoster.putIfAbsent(pick.rosterId, () => []);
        picksByRoster[pick.rosterId]!.add(pick);
      }
    }

    // Sort picks within each roster by pick number and assign slot indices
    for (var entry in picksByRoster.entries) {
      final rosterId = entry.key;
      final rosterPicks = entry.value;

      // Sort by pick number
      rosterPicks.sort((a, b) => a.pickNumber.compareTo(b.pickNumber));

      // Assign slot indices (0, 1, 2, etc.)
      picksByRosterAndSlot[rosterId] = {};
      for (var i = 0; i < rosterPicks.length; i++) {
        picksByRosterAndSlot[rosterId]![i] = rosterPicks[i];
      }
    }

    return DataTable(
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
              'Position',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
        ...order.map((team) => DataColumn(
          label: Container(
            width: 100,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      team.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: team.isAutodrafting
                            ? Colors.amber.shade700
                            : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (team.isAutodrafting) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.auto_mode,
                      size: 12,
                      color: Colors.amber.shade700,
                    ),
                  ],
                ],
              ),
            ),
          ),
        )),
      ],
      rows: _expandRosterPositions(rosterPositions).asMap().entries.map((entry) {
        final slotIndex = entry.key;
        final position = entry.value;

        return DataRow(
          cells: [
            // Position cell
            DataCell(
              Container(
                width: 60,
                child: Center(
                  child: Text(
                    position,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            // Create a cell for each team's pick in this slot
            ...order.map((team) {
              final pick = picksByRosterAndSlot[team.rosterId]?[slotIndex];
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
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                    'R${pick?.round}',
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
    );
  }
}
