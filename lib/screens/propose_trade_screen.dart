import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trade_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/roster_model.dart';
import '../models/player_model.dart';
import '../services/player_service.dart';

class ProposeTradeScreen extends StatefulWidget {
  final int leagueId;
  final int myRosterId;

  const ProposeTradeScreen({
    super.key,
    required this.leagueId,
    required this.myRosterId,
  });

  @override
  State<ProposeTradeScreen> createState() => _ProposeTradeScreenState();
}

class _ProposeTradeScreenState extends State<ProposeTradeScreen> {
  final PlayerService _playerService = PlayerService();
  Roster? _selectedRoster;
  List<Player> _mySelectedPlayers = [];
  List<Player> _theirSelectedPlayers = [];
  bool _notifyLeagueChat = true;
  bool _showProposalDetails = false;

  Map<int, List<Player>> _rosterPlayersCache = {}; // Cache fetched players
  bool _isLoadingPlayers = false;

  // Get all player IDs from a roster
  List<int> _getPlayerIdsFromRoster(Roster roster) {
    List<int> playerIds = [];

    // Get player IDs from starters (they are objects with player_id)
    for (var starter in roster.starters) {
      if (starter is Map && starter['player_id'] != null) {
        playerIds.add(starter['player_id'] as int);
      }
    }

    // Get player IDs from bench, taxi, ir (they are just IDs)
    for (var playerId in roster.bench) {
      if (playerId is int) {
        playerIds.add(playerId);
      }
    }
    for (var playerId in roster.taxi) {
      if (playerId is int) {
        playerIds.add(playerId);
      }
    }
    for (var playerId in roster.ir) {
      if (playerId is int) {
        playerIds.add(playerId);
      }
    }

    return playerIds;
  }

  // Fetch players for a roster
  Future<List<Player>> _fetchRosterPlayers(Roster roster) async {
    // Check cache first
    if (_rosterPlayersCache.containsKey(roster.id)) {
      return _rosterPlayersCache[roster.id]!;
    }

    setState(() => _isLoadingPlayers = true);

    try {
      final playerIds = _getPlayerIdsFromRoster(roster);

      // Fetch players in bulk (more efficient than one by one)
      final players = await _playerService.getPlayersByIds(playerIds);

      // Cache the results
      _rosterPlayersCache[roster.id] = players;

      setState(() => _isLoadingPlayers = false);
      return players;
    } catch (e) {
      setState(() => _isLoadingPlayers = false);
      debugPrint('Error fetching roster players: \$e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final leagueProvider = Provider.of<LeagueProvider>(context);
    final tradeProvider = Provider.of<TradeProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final rosters = leagueProvider.selectedLeagueRosters
        .where((r) => r.id != widget.myRosterId)
        .toList();

    final myRoster = leagueProvider.selectedLeagueRosters
        .firstWhere((r) => r.id == widget.myRosterId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Propose Trade'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select trading partner
            DropdownButtonFormField<Roster>(
              value: _selectedRoster,
              decoration: const InputDecoration(
                labelText: 'Trade With',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select a team to trade with'),
              items: rosters.map((roster) {
                return DropdownMenuItem(
                  value: roster,
                  child: Text(roster.settings?["team_name"] ?? 'Team ${roster.rosterId}'),
                );
              }).toList(),
              onChanged: (roster) {
                setState(() {
                  _selectedRoster = roster;
                  _theirSelectedPlayers.clear();
                });
                // Preload their players
                if (roster != null) {
                  _fetchRosterPlayers(roster);
                }
              },
            ),
            const SizedBox(height: 24),

            // My players
            Text(
              'I Give:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Player>>(
              future: _fetchRosterPlayers(myRoster),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Error loading players'),
                    ),
                  );
                }
                return _buildPlayerSelector(snapshot.data!, _mySelectedPlayers);
              },
            ),
            const SizedBox(height: 24),

            // Their players
            if (_selectedRoster != null) ...[
              Text(
                'I Receive:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Player>>(
                future: _fetchRosterPlayers(_selectedRoster!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Error loading players'),
                      ),
                    );
                  }
                  return _buildPlayerSelector(snapshot.data!, _theirSelectedPlayers);
                },
              ),
              const SizedBox(height: 24),
            ],

            // Trade settings
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notify League Chat'),
                    subtitle: const Text('Post trade proposal notification to league chat'),
                    value: _notifyLeagueChat,
                    onChanged: (value) {
                      setState(() {
                        _notifyLeagueChat = value;
                        if (!value) {
                          _showProposalDetails = false; // Reset when notification is turned off
                        }
                      });
                    },
                  ),
                  if (_notifyLeagueChat) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Show Proposal Details'),
                      subtitle: const Text('Display full trade details in league chat'),
                      value: _showProposalDetails,
                      onChanged: (value) {
                        setState(() {
                          _showProposalDetails = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            FilledButton(
              onPressed: (_selectedRoster != null &&
                      (_mySelectedPlayers.isNotEmpty ||
                          _theirSelectedPlayers.isNotEmpty) &&
                      !_isLoadingPlayers)
                  ? () async {
                      final success = await tradeProvider.proposeTrade(
                        token: authProvider.token!,
                        leagueId: widget.leagueId,
                        proposerRosterId: widget.myRosterId,
                        receiverRosterId: _selectedRoster!.id,
                        playersGiving:
                            _mySelectedPlayers.map((p) => p.id).toList(),
                        playersReceiving:
                            _theirSelectedPlayers.map((p) => p.id).toList(),
                        message: null,
                        notifyLeagueChat: _notifyLeagueChat,
                        showProposalDetails: _showProposalDetails,
                      );

                      if (context.mounted) {
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Trade proposed!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to propose trade'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Propose Trade'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSelector(List<Player> availablePlayers, List<Player> selectedPlayers) {
    if (availablePlayers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No players available'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          if (selectedPlayers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No players selected'),
            )
          else
            ...selectedPlayers.map((player) => ListTile(
                  leading: CircleAvatar(
                    child: Text(player.position[0]),
                  ),
                  title: Text(player.fullName),
                  subtitle: Text('${player.position} - ${player.team ?? "FA"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () {
                      setState(() {
                        selectedPlayers.remove(player);
                      });
                    },
                  ),
                )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilledButton.icon(
              onPressed: () {
                _showPlayerPicker(availablePlayers, selectedPlayers);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Player'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerPicker(List<Player> allPlayers, List<Player> selectedPlayers) {
    final availablePlayers = allPlayers
        .where((p) => !selectedPlayers.contains(p))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Player'),
          content: SizedBox(
            width: double.maxFinite,
            child: availablePlayers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('All players already selected'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: availablePlayers.length,
                    itemBuilder: (context, index) {
                      final player = availablePlayers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(player.position[0]),
                        ),
                        title: Text(player.fullName),
                        subtitle: Text('${player.position} - ${player.team ?? "FA"}'),
                        onTap: () {
                          setState(() {
                            selectedPlayers.add(player);
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
