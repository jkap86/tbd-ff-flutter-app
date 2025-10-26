import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/weekly_lineup_service.dart';
import '../services/roster_service.dart';

class WeeklyLineupScreen extends StatefulWidget {
  final int rosterId;
  final String rosterName;
  final int week;
  final String season;

  const WeeklyLineupScreen({
    super.key,
    required this.rosterId,
    required this.rosterName,
    required this.week,
    required this.season,
  });

  @override
  State<WeeklyLineupScreen> createState() => _WeeklyLineupScreenState();
}

class _WeeklyLineupScreenState extends State<WeeklyLineupScreen> {
  final WeeklyLineupService _weeklyLineupService = WeeklyLineupService();
  final RosterService _rosterService = RosterService();
  Map<String, dynamic>? _lineupData;
  Map<String, dynamic>? _rosterData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isEditMode = false;
  bool _isSaving = false;

  // Temporary lists for editing
  List<dynamic> _editStarters = [];
  List<dynamic> _editBench = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

    // Load weekly lineup and full roster data in parallel
    final lineup = await _weeklyLineupService.getWeeklyLineup(
      token: token,
      rosterId: widget.rosterId,
      week: widget.week,
      season: widget.season,
    );

    final roster = await _rosterService.getRosterWithPlayers(token, widget.rosterId);

    setState(() {
      _lineupData = lineup;
      _rosterData = roster;
      _isLoading = false;
      if (lineup == null || roster == null) {
        _errorMessage = 'Failed to load lineup';
      }
    });
  }

  void _enterEditMode() {
    if (_lineupData == null || _rosterData == null) return;

    setState(() {
      _isEditMode = true;
      // Start with the weekly lineup starters
      _editStarters = List.from(_lineupData!['starters'] as List<dynamic>);

      // Build bench from all roster players NOT in starters
      final starterPlayerIds = _editStarters
          .map((slot) => slot['player']?['id'])
          .where((id) => id != null)
          .toSet();

      final allPlayers = List.from(_rosterData!['bench'] as List<dynamic>? ?? []);
      final rosterStarters = _rosterData!['starters'] as List<dynamic>? ?? [];

      // Add players from roster starters that aren't in weekly lineup
      for (var slot in rosterStarters) {
        final player = slot['player'];
        if (player != null && !starterPlayerIds.contains(player['id'])) {
          allPlayers.add(player);
        }
      }

      // Add players from bench
      _editBench = allPlayers.where((p) => p != null).toList();
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
    setState(() {
      _isSaving = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
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

    final result = await _weeklyLineupService.updateWeeklyLineup(
      token: token,
      rosterId: widget.rosterId,
      week: widget.week,
      season: widget.season,
      starters: starterSlots,
    );

    setState(() {
      _isSaving = false;
    });

    if (result != null) {
      setState(() {
        _lineupData = result;
        _isEditMode = false;
        _editStarters = [];
        _editBench = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Week ${widget.week} lineup updated! Go to Matchups and click "Update Scores" to recalculate.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update lineup'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.rosterName} - Week ${widget.week}'),
        actions: [
          if (!_isEditMode && _lineupData != null)
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
          ? const Center(child: CircularProgressIndicator())
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
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildLineupContent(),
    );
  }

  Widget _buildLineupContent() {
    if (_lineupData == null) return const SizedBox();

    final starters = _isEditMode ? _editStarters : (_lineupData!['starters'] as List<dynamic>? ?? []);
    final bench = _isEditMode ? _editBench : (_rosterData!['bench'] as List<dynamic>? ?? []);

    int starterCount = starters.where((s) => s['player'] != null).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Week ${widget.week} Lineup (${widget.season} Season)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Move players between starters and bench using the buttons',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Starters Section
            if (starters.isNotEmpty) ...[
              _buildSectionHeader('Starters', starterCount, Colors.green),
              const SizedBox(height: 8),
              ...List.generate(starters.length, (index) {
                final slotData = starters[index];
                return _buildSlotCard(slotData, index);
              }),
              const SizedBox(height: 24),
            ],

            // Bench Section
            if (bench.isNotEmpty) ...[
              _buildSectionHeader('Bench', bench.length, Colors.orange),
              const SizedBox(height: 8),
              ...bench.map((player) => _buildPlayerCard(player)),
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
            color: color.withOpacity(0.2),
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

  Widget _buildPlayerCard(dynamic player) {
    if (player == null) return const SizedBox();

    final fullName = player['full_name'] ?? 'Unknown Player';
    final position = player['position'] ?? '?';
    final team = player['team'] ?? 'FA';

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
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(team),
        trailing: _isEditMode
            ? PopupMenuButton<int>(
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
                            assignedPlayer != null
                                ? '(${assignedPlayer['full_name']})'
                                : '(Empty)',
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
              )
            : null,
      ),
    );
  }

  Widget _buildSlotCard(dynamic slotData, int slotIndex) {
    final slot = slotData['slot'] as String;
    final player = slotData['player'];

    if (player == null) {
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

    final fullName = player['full_name'] ?? 'Unknown Player';
    final position = player['position'] ?? '?';
    final team = player['team'] ?? 'FA';

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
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(team),
        trailing: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _removePlayerFromSlot(slotIndex),
                tooltip: 'Remove from slot',
              )
            : null,
      ),
    );
  }

  bool _isPlayerEligibleForSlot(dynamic player, String slot) {
    final position = player['position'] as String?;
    if (position == null) return false;

    final baseSlot = slot.replaceAll(RegExp(r'\d+$'), '');

    if (position == baseSlot) return true;

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
