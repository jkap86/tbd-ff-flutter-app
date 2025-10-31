import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/roster_service.dart';
import '../services/weekly_lineup_service.dart';
import '../widgets/injury_badge_widget.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/loading_skeletons.dart';
import '../models/player_model.dart';

class RosterDetailsScreen extends StatefulWidget {
  final int rosterId;
  final String rosterName;
  final String? season;
  final int? currentWeek;

  const RosterDetailsScreen({
    super.key,
    required this.rosterId,
    required this.rosterName,
    this.season,
    this.currentWeek,
  });

  @override
  State<RosterDetailsScreen> createState() => _RosterDetailsScreenState();
}

class _RosterDetailsScreenState extends State<RosterDetailsScreen> {
  final RosterService _rosterService = RosterService();
  final WeeklyLineupService _weeklyLineupService = WeeklyLineupService();
  Map<String, dynamic>? _rosterData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isEditMode = false;
  bool _isSaving = false;
  int? _selectedWeek;

  // Temporary lists for editing
  List<dynamic> _editStarters = []; // List of {slot: string, player: {player data} | null}
  List<dynamic> _editBench = []; // List of player objects

  @override
  void initState() {
    super.initState();
    _selectedWeek = widget.currentWeek;
    _loadRoster();
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _editStarters = List.from(_rosterData!['starters'] as List<dynamic>);
      _editBench = List.from(_rosterData!['bench'] as List<dynamic>);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _editStarters = [];
      _editBench = [];
    });
  }

  Future<void> _saveLineup() async {
    debugPrint('[RosterDetails] Starting lineup save...');
    setState(() {
      _isSaving = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    debugPrint('[RosterDetails] Token: ${token != null ? "present" : "missing"}');

    if (token == null) {
      debugPrint('[RosterDetails] No token, aborting');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Build starter slots with their assignments
    final starterSlots = _editStarters.map((slotData) {
      return {
        'slot': slotData['slot'],
        'player_id': slotData['player']?['id'],
      };
    }).toList();

    try {
      dynamic result;

      // If week is selected and season is available, use weekly lineup
      if (_selectedWeek != null && widget.season != null) {
        debugPrint('[RosterDetails] Saving weekly lineup for week $_selectedWeek...');
        result = await _weeklyLineupService.updateWeeklyLineup(
          token: token,
          rosterId: widget.rosterId,
          week: _selectedWeek!,
          season: widget.season!,
          starters: starterSlots,
        );
      } else {
        // Otherwise save default roster lineup
        debugPrint('[RosterDetails] Saving default roster lineup...');
        // Extract player IDs for bench
        final benchIds = _editBench
            .where((p) => p != null)
            .map((p) => p['id'] as int)
            .toList();

        result = await _rosterService.updateRosterLineup(
          token,
          widget.rosterId,
          starters: starterSlots,
          bench: benchIds,
        );
      }

      setState(() {
        _isSaving = false;
      });

      if (result != null) {
        // Reload the roster to get fresh data
        await _loadRoster();

        setState(() {
          _isEditMode = false;
          _editStarters = [];
          _editBench = [];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_selectedWeek != null
              ? 'Week $_selectedWeek lineup updated successfully'
              : 'Lineup updated successfully')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _assignPlayerToSlot(int slotIndex, dynamic player) {
    setState(() {
      // Remove player from bench
      _editBench.remove(player);

      // Assign player to slot
      _editStarters[slotIndex]['player'] = player;
    });
  }

  void _removePlayerFromSlot(int slotIndex) {
    setState(() {
      final player = _editStarters[slotIndex]['player'];

      if (player != null) {
        // Remove from slot
        _editStarters[slotIndex]['player'] = null;

        // Add back to bench
        _editBench.add(player);
      }
    });
  }

  Future<void> _loadRoster() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      setState(() {
        _errorMessage = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    dynamic roster;

    // If week is selected and season is available, load weekly lineup
    if (_selectedWeek != null && widget.season != null) {
      debugPrint('[RosterDetails] Loading weekly lineup for week $_selectedWeek...');

      // Load both weekly lineup (for starters) and full roster (for bench)
      final weeklyLineup = await _weeklyLineupService.getWeeklyLineup(
        token: token,
        rosterId: widget.rosterId,
        week: _selectedWeek!,
        season: widget.season!,
      );

      final fullRoster = await _rosterService.getRosterWithPlayers(token, widget.rosterId);

      // Use weekly lineup starters with bench from full roster
      if (weeklyLineup != null && fullRoster != null) {
        roster = {
          ...fullRoster,
          'starters': weeklyLineup['starters'],
        };

        debugPrint('[RosterDetails] Using weekly lineup starters + bench array from full roster');
      } else {
        roster = fullRoster; // Fallback to full roster if weekly lineup doesn't exist
      }
    } else {
      // Otherwise load default roster
      debugPrint('[RosterDetails] Loading default roster...');
      roster = await _rosterService.getRosterWithPlayers(token, widget.rosterId);
    }

    setState(() {
      _rosterData = roster;
      _isLoading = false;
      if (roster == null) {
        _errorMessage = 'Failed to load roster';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.rosterName, style: const TextStyle(fontSize: 18)),
            if (_selectedWeek != null)
              Text(
                'Week $_selectedWeek',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          // Week selector dropdown (only show if season is available)
          if (widget.season != null && !_isEditMode)
            PopupMenuButton<int?>(
              tooltip: 'Select Week',
              onSelected: (week) {
                setState(() {
                  _selectedWeek = week;
                });
                _loadRoster();
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<int?>(
                    value: null,
                    child: Text('Default Roster'),
                  ),
                  const PopupMenuDivider(),
                  ...List.generate(18, (index) {
                    final week = index + 1;
                    return PopupMenuItem<int>(
                      value: week,
                      child: Row(
                        children: [
                          if (week == _selectedWeek)
                            const Icon(Icons.check, size: 16),
                          if (week == _selectedWeek)
                            const SizedBox(width: 8),
                          Text('Week $week'),
                        ],
                      ),
                    );
                  }),
                ];
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedWeek == null ? 'Default' : 'Week $_selectedWeek',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
              ),
            ),
          if (!_isEditMode && _rosterData != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _enterEditMode,
              tooltip: 'Edit Lineup',
            ),
          if (_isEditMode) ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveLineup,
              tooltip: 'Save Lineup',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const RosterSectionSkeleton(itemCount: 10)
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRoster,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildRosterContent(),
    );
  }

  Widget _buildRosterContent() {
    if (_rosterData == null) return const SizedBox();

    // Use edit lists in edit mode, otherwise use actual data
    final starters = _isEditMode ? _editStarters : (_rosterData!['starters'] as List<dynamic>? ?? []);
    final bench = _isEditMode ? _editBench : (_rosterData!['bench'] as List<dynamic>? ?? []);
    final taxi = _rosterData!['taxi'] as List<dynamic>? ?? [];
    final ir = _rosterData!['ir'] as List<dynamic>? ?? [];

    // Count total players
    final starterCount = starters.where((s) => s['player'] != null).length;
    final totalPlayers = starterCount + bench.length + taxi.length + ir.length;

    // Get positions that exist in roster slots (to determine which positions to show)
    final rosterPositions = <String>{};
    for (final slot in starters) {
      final slotName = slot['slot'] as String?;
      if (slotName != null) {
        // Extract base position (e.g., "QB1" -> "QB", "FLEX" -> "FLEX")
        final basePosition = slotName.replaceAll(RegExp(r'\d+$'), '');

        // Map FLEX positions to their component positions
        if (basePosition == 'FLEX') {
          rosterPositions.addAll(['RB', 'WR', 'TE']);
        } else if (basePosition == 'SUPER_FLEX') {
          rosterPositions.addAll(['QB', 'RB', 'WR', 'TE']);
        } else if (basePosition == 'WRT') {
          rosterPositions.addAll(['WR', 'RB', 'TE']);
        } else if (basePosition == 'REC_FLEX') {
          rosterPositions.addAll(['WR', 'TE']);
        } else if (basePosition == 'IDP_FLEX') {
          rosterPositions.addAll(['DL', 'LB', 'DB']);
        } else {
          rosterPositions.add(basePosition);
        }
      }
    }

    // Count players by position
    Map<String, int> countByPosition(List<dynamic> players) {
      final counts = <String, int>{};
      for (final player in players) {
        final position = player['position'] as String?;
        if (position != null) {
          counts[position] = (counts[position] ?? 0) + 1;
        }
      }
      return counts;
    }

    // Get all players from starters (non-null only) and bench
    final allPlayers = <dynamic>[];
    for (final slot in starters) {
      final player = slot['player'];
      if (player != null) {
        allPlayers.add(player);
      }
    }
    allPlayers.addAll(bench);

    final positionCounts = countByPosition(allPlayers);

    // Calculate roster size validation
    final totalRosterSlots = starters.length;
    // starterCount includes all filled slots (QB, RB, WR, BN, etc.)
    final totalPlayersOnRoster = starterCount + taxi.length + ir.length;
    final excessPlayers = totalPlayersOnRoster - totalRosterSlots;
    final hasExcessPlayers = excessPlayers > 0;

    return RefreshIndicator(
      onRefresh: _loadRoster,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Roster Size Validation Warning
            if (hasExcessPlayers) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Too Many Players on Roster',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You have $totalPlayersOnRoster players but only $totalRosterSlots roster slots. Please drop $excessPlayers ${excessPlayers == 1 ? 'player' : 'players'} to meet league requirements.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Roster Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          child: Text(
                            'R${_rosterData!['roster_id']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _rosterData!['username'] ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _rosterData!['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Record and Points
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatChip(
                          'Record',
                          '${_rosterData!['settings']?['wins'] ?? 0}-${_rosterData!['settings']?['losses'] ?? 0}-${_rosterData!['settings']?['ties'] ?? 0}',
                          Colors.teal,
                        ),
                        _buildStatChip(
                          'PF',
                          (_rosterData!['settings']?['points_for'] ?? 0.0).toStringAsFixed(2),
                          Colors.green,
                        ),
                        _buildStatChip(
                          'PA',
                          (_rosterData!['settings']?['points_against'] ?? 0.0).toStringAsFixed(2),
                          Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Total players and position breakdown evenly spaced
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatChip('Total', totalPlayers.toString(), Colors.blue),
                        if (rosterPositions.contains('QB'))
                          _buildStatChip('QB', (positionCounts['QB'] ?? 0).toString(), Colors.red),
                        if (rosterPositions.contains('RB'))
                          _buildStatChip('RB', (positionCounts['RB'] ?? 0).toString(), Colors.green),
                        if (rosterPositions.contains('WR'))
                          _buildStatChip('WR', (positionCounts['WR'] ?? 0).toString(), Colors.blue),
                        if (rosterPositions.contains('TE'))
                          _buildStatChip('TE', (positionCounts['TE'] ?? 0).toString(), Colors.orange),
                        if (rosterPositions.contains('K'))
                          _buildStatChip('K', (positionCounts['K'] ?? 0).toString(), Colors.purple),
                        if (rosterPositions.contains('DEF'))
                          _buildStatChip('DEF', (positionCounts['DEF'] ?? 0).toString(), Colors.brown),
                        // IDP positions
                        if (rosterPositions.contains('DL'))
                          _buildStatChip('DL', (positionCounts['DL'] ?? 0).toString(), Colors.grey),
                        if (rosterPositions.contains('LB'))
                          _buildStatChip('LB', (positionCounts['LB'] ?? 0).toString(), Colors.grey),
                        if (rosterPositions.contains('DB'))
                          _buildStatChip('DB', (positionCounts['DB'] ?? 0).toString(), Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Edit Mode Banner
            if (_isEditMode) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Move players between starters and bench using the arrow buttons',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Starters Section
            () {
              final starterCount = starters.where((s) => s['player'] != null).length;

              if (starters.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Starters', starterCount, Colors.green),
                    const SizedBox(height: 8),
                    ...List.generate(starters.length, (index) {
                      return _buildSlotCard(starters[index], index);
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Starters', 0, Colors.green),
                    const SizedBox(height: 8),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No starter slots configured',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }
            }(),

            // Bench Section (bench array only)
            if (bench.isNotEmpty) ...[
              _buildSectionHeader('Bench', bench.length, Colors.orange),
              const SizedBox(height: 8),
              ...bench.map((player) => _buildPlayerCard(player, 'bench')),
              const SizedBox(height: 24),
            ],

            // Taxi Section
            if (taxi.isNotEmpty) ...[
              _buildSectionHeader('Taxi Squad', taxi.length, Colors.purple),
              const SizedBox(height: 8),
              ...taxi.map((player) => _buildPlayerCard(player, 'taxi')),
              const SizedBox(height: 24),
            ],

            // IR Section
            if (ir.isNotEmpty) ...[
              _buildSectionHeader('Injured Reserve', ir.length, Colors.red),
              const SizedBox(height: 8),
              ...ir.map((player) => _buildPlayerCard(player, 'ir')),
            ],

            // Empty roster message
            if (totalPlayers == 0) ...[
              const EmptyStateWidget(
                icon: Icons.group_off,
                title: 'No players on roster',
                subtitle: 'Players will be added after the draft',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(dynamic player, String section) {
    if (player == null) {
      return const Card(
        margin: EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.help_outline),
          ),
          title: Text('Unknown Player'),
          subtitle: Text('Player data not available'),
        ),
      );
    }

    final fullName = player['full_name'] ?? 'Unknown Player';
    final position = player['position'] ?? '?';
    final team = player['team'] ?? 'FA';
    final age = player['age'];
    final yearsExp = player['years_exp'];

    // Create Player object to access injury badge
    final playerObj = Player.fromJson(player);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPositionColor(position),
          child: Text(
            position,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            InjuryBadgeWidget(player: playerObj),
          ],
        ),
        subtitle: Text(
          '$team${age != null ? ' • Age $age' : ''}${yearsExp != null ? ' • $yearsExp yr exp' : ''}',
        ),
        trailing: _isEditMode ? _buildMoveButtons(player, section) : Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: _isEditMode ? null : () {
          // TODO: Navigate to player details screen
        },
      ),
    );
  }

  Widget _buildSlotCard(dynamic slotData, int slotIndex) {
    final slot = slotData['slot'] as String;
    final player = slotData['player'];

    if (player == null) {
      // Empty slot
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.grey.shade100,
        child: ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                slot,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          title: Text(
            'Empty $slot',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
          subtitle: Text(
            _isEditMode ? 'Tap a bench player to assign' : 'No player assigned',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
      );
    }

    // Slot with player assigned
    final fullName = player['full_name'] ?? 'Unknown Player';
    final position = player['position'] ?? '?';
    final team = player['team'] ?? 'FA';
    final age = player['age'];
    final yearsExp = player['years_exp'];

    // Create Player object to access injury badge
    final playerObj = Player.fromJson(player);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getPositionColor(position),
              child: Text(
                position,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  slot,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            InjuryBadgeWidget(player: playerObj),
          ],
        ),
        subtitle: Text(
          '$team${age != null ? ' • Age $age' : ''}${yearsExp != null ? ' • $yearsExp yr exp' : ''}',
        ),
        trailing: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _removePlayerFromSlot(slotIndex),
                tooltip: 'Remove from slot',
              )
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
        onTap: _isEditMode ? null : () {
          // TODO: Navigate to player details screen
        },
      ),
    );
  }

  Widget _buildMoveButtons(dynamic player, String section) {
    // This is now only used for bench players in edit mode
    if (section == 'bench' && _isEditMode) {
      return PopupMenuButton<int>(
        icon: const Icon(Icons.add_circle, color: Colors.green),
        tooltip: 'Assign to slot',
        onSelected: (slotIndex) => _assignPlayerToSlot(slotIndex, player),
        itemBuilder: (context) {
          return List.generate(_editStarters.length, (index) {
            final slotData = _editStarters[index];
            final slot = slotData['slot'];
            final assignedPlayer = slotData['player'];
            final isEligible = _isPlayerEligibleForSlot(player, slot);

            return PopupMenuItem<int>(
              value: index,
              enabled: assignedPlayer == null && isEligible,
              child: Row(
                children: [
                  Text(
                    slot,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isEligible ? Colors.black : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    assignedPlayer != null ? '(${assignedPlayer['full_name']})' : '(Empty)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (!isEligible)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.block, size: 16, color: Colors.red),
                    ),
                ],
              ),
            );
          });
        },
      );
    }

    // For taxi/IR, don't show buttons
    return Icon(
      Icons.arrow_forward_ios,
      size: 16,
      color: Colors.grey.shade400,
    );
  }

  bool _isPlayerEligibleForSlot(dynamic player, String slot) {
    final position = player['position'] as String?;
    if (position == null) return false;

    // Extract base slot name (remove numbers like QB1 -> QB)
    final baseSlot = slot.replaceAll(RegExp(r'\d+$'), '');

    // Exact match
    if (position == baseSlot) return true;

    // FLEX positions
    if (baseSlot == 'FLEX') {
      return ['RB', 'WR', 'TE'].contains(position);
    }
    if (baseSlot == 'SUPER_FLEX') {
      return ['QB', 'RB', 'WR', 'TE'].contains(position);
    }
    if (baseSlot == 'WRT') {
      return ['WR', 'RB', 'TE'].contains(position);
    }
    if (baseSlot == 'REC_FLEX') {
      return ['WR', 'TE'].contains(position);
    }
    if (baseSlot == 'IDP_FLEX') {
      return ['DL', 'LB', 'DB'].contains(position);
    }

    return false;
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
      default:
        return Colors.grey.shade400;
    }
  }
}
