import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/waiver_provider.dart';
import '../../models/player_model.dart';
import '../../models/roster_model.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../config/api_config.dart';
import '../../widgets/waiver/submit_claim_dialog.dart';
import '../../widgets/injury_badge_widget.dart';

class AvailablePlayersScreen extends StatefulWidget {
  final int leagueId;
  final Roster userRoster;

  const AvailablePlayersScreen({
    super.key,
    required this.leagueId,
    required this.userRoster,
  });

  @override
  State<AvailablePlayersScreen> createState() => _AvailablePlayersScreenState();
}

class _AvailablePlayersScreenState extends State<AvailablePlayersScreen> {
  List<Player> _players = [];
  List<int> _rosterPlayerIds = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _positionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get all rostered players in the league
      final rostersResponse = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/leagues/${widget.leagueId}'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (rostersResponse.statusCode == 200) {
        final rostersData = jsonDecode(rostersResponse.body);
        final rosters = rostersData['data']['rosters'] as List;

        debugPrint('[AvailablePlayers] Found ${rosters.length} rosters');

        // Collect all player IDs from all rosters
        Set<int> rosteredIds = {};
        for (var roster in rosters) {
          final starters = roster['starters'] as List? ?? [];
          final bench = roster['bench'] as List? ?? [];
          final taxi = roster['taxi'] as List? ?? [];
          final ir = roster['ir'] as List? ?? [];

          debugPrint('[AvailablePlayers] Roster has ${starters.length} starters, ${bench.length} bench');
          if (starters.isNotEmpty) {
            debugPrint('[AvailablePlayers] First starter: ${starters[0]}');
          }
          if (bench.isNotEmpty) {
            debugPrint('[AvailablePlayers] First bench: ${bench[0]}');
          }

          // Extract player IDs from starters (format: {slot: 'QB', player_id: 123} or {slot: 'QB', player: {...}})
          for (var item in starters) {
            if (item is Map) {
              // Check for direct player_id field first
              var playerId = item['player_id'];

              // If not found, check for nested player object
              if (playerId == null) {
                final player = item['player'];
                if (player != null && player is Map) {
                  playerId = player['id'] ?? player['player_id'];
                }
              }

              if (playerId != null) {
                rosteredIds.add(playerId as int);
                debugPrint('[AvailablePlayers] Added starter player ID: $playerId');
              }
            }
          }

          // Extract player IDs from bench (format: [{id: 123, ...playerData}] or [123])
          for (var item in bench) {
            if (item is int) {
              rosteredIds.add(item);
              debugPrint('[AvailablePlayers] Added bench player ID (int): $item');
            } else if (item is Map) {
              final playerId = item['id'] ?? item['player_id'];
              if (playerId != null) {
                rosteredIds.add(playerId as int);
                debugPrint('[AvailablePlayers] Added bench player ID (map): $playerId');
              }
            }
          }

          // Extract player IDs from taxi
          for (var item in taxi) {
            if (item is int) {
              rosteredIds.add(item);
            } else if (item is Map) {
              final playerId = item['id'] ?? item['player_id'];
              if (playerId != null) rosteredIds.add(playerId as int);
            }
          }

          // Extract player IDs from ir
          for (var item in ir) {
            if (item is int) {
              rosteredIds.add(item);
            } else if (item is Map) {
              final playerId = item['id'] ?? item['player_id'];
              if (playerId != null) rosteredIds.add(playerId as int);
            }
          }
        }

        _rosterPlayerIds = rosteredIds.toList();
        debugPrint('[AvailablePlayers] Total rostered player IDs: ${_rosterPlayerIds.length}');
        debugPrint('[AvailablePlayers] Rostered IDs: $_rosterPlayerIds');
      }

      // Get all players (you may want to add pagination or filtering on backend)
      final playersResponse = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/players'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (playersResponse.statusCode == 200) {
        final playersData = jsonDecode(playersResponse.body);
        final playersList = playersData['data'] as List;

        setState(() {
          _players = playersList
              .map((json) => Player.fromJson(json))
              .where((player) => !_rosterPlayerIds.contains(player.id))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load players';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading players: $e';
        _isLoading = false;
      });
    }
  }

  List<Player> get _filteredPlayers {
    var filtered = _players;

    // Apply position filter
    if (_positionFilter != 'ALL') {
      filtered = filtered.where((p) => p.position == _positionFilter).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.team?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
          .toList();
    }

    return filtered;
  }

  bool _isOnWaivers(Player player) {
    // For now, all available players require waiver claims
    // TODO: Backend will determine if they're on waivers based on drop time
    return true;
  }

  void _showPlayerActions(Player player) {
    final isOnWaivers = _isOnWaivers(player);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(player.fullName),
                subtitle: Text(player.positionTeam),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  isOnWaivers ? Icons.access_time : Icons.check_circle,
                  color: isOnWaivers ? Colors.orange : Colors.green,
                ),
                title: Text(isOnWaivers ? 'Submit Waiver Claim' : 'Add Free Agent'),
                onTap: () {
                  Navigator.pop(context);
                  if (isOnWaivers) {
                    _showSubmitClaimDialog(player);
                  } else {
                    _showAddFreeAgentDialog(player);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubmitClaimDialog(Player player) {
    showDialog(
      context: context,
      builder: (context) => SubmitClaimDialog(
        leagueId: widget.leagueId,
        userRoster: widget.userRoster,
        player: player,
      ),
    );
  }

  void _showAddFreeAgentDialog(Player player) {
    // For free agents, show a simpler dialog with optional drop player
    showDialog(
      context: context,
      builder: (context) => SubmitClaimDialog(
        leagueId: widget.leagueId,
        userRoster: widget.userRoster,
        player: player,
        isFreeAgent: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Players'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search players...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip('ALL'),
                    _buildFilterChip('QB'),
                    _buildFilterChip('RB'),
                    _buildFilterChip('WR'),
                    _buildFilterChip('TE'),
                    _buildFilterChip('K'),
                    _buildFilterChip('DEF'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPlayers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _filteredPlayers.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.search_off,
                      title: 'No players found',
                      subtitle: 'Try adjusting your search or filters',
                    )
                  : ListView.builder(
                      itemCount: _filteredPlayers.length,
                      itemBuilder: (context, index) {
                        final player = _filteredPlayers[index];
                        final isOnWaivers = _isOnWaivers(player);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getPositionColor(player.position),
                              child: Text(
                                player.position,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(player.fullName)),
                                const SizedBox(width: 8),
                                InjuryBadgeWidget(player: player),
                              ],
                            ),
                            subtitle: Text(player.positionTeam),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isOnWaivers
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOnWaivers ? 'WAIVER' : 'FA',
                                style: TextStyle(
                                  color: isOnWaivers ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () => _showPlayerActions(player),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildFilterChip(String position) {
    final isSelected = _positionFilter == position;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(position),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _positionFilter = position;
          });
        },
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case 'QB':
        return Colors.red;
      case 'RB':
        return Colors.blue;
      case 'WR':
        return Colors.green;
      case 'TE':
        return Colors.orange;
      case 'K':
        return Colors.purple;
      case 'DEF':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
