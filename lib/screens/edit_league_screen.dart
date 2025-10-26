import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../providers/draft_provider.dart';
import '../models/league_model.dart';
import '../models/roster_model.dart';
import '../services/draft_service.dart';
import '../services/league_service.dart';
import '../widgets/responsive_container.dart';

class EditLeagueScreen extends StatefulWidget {
  final League league;

  const EditLeagueScreen({
    super.key,
    required this.league,
  });

  @override
  State<EditLeagueScreen> createState() => _EditLeagueScreenState();
}

class _EditLeagueScreenState extends State<EditLeagueScreen> {
  late TextEditingController _nameController;
  bool _isPublic = false;
  int _totalRosters = 12;
  String _seasonType = 'regular';
  int _startWeek = 1;
  int _endWeek = 17;
  int _playoffWeekStart = 15;
  late Map<String, dynamic> _scoringSettings;
  late Map<String, int> _rosterPositions;
  bool _isResetting = false;

  // Draft settings
  String _draftType = 'snake';
  bool _thirdRoundReversal = false;
  int _pickTimeSeconds = 90;
  int _draftRounds = 15;

  // Commissioner
  int? _commissionerId;

  // Scoring settings fields
  late TextEditingController _passingTouchdownsController;
  late TextEditingController _passingYardsController;
  late TextEditingController _rushingTouchdownsController;
  late TextEditingController _rushingYardsController;
  late TextEditingController _receivingTouchdownsController;
  late TextEditingController _receivingYardsController;
  late TextEditingController _receivingReceptionsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.league.name);
    _isPublic = widget.league.settings?['is_public'] ?? false;
    _totalRosters = widget.league.totalRosters;
    _seasonType = widget.league.seasonType;
    _startWeek = widget.league.settings?['start_week'] ?? 1;
    _endWeek = widget.league.settings?['end_week'] ?? 17;
    _playoffWeekStart = widget.league.settings?['playoff_week_start'] ?? 15;
    _scoringSettings = widget.league.scoringSettings ?? {};

    // Initialize commissioner
    _commissionerId = widget.league.settings?['commissioner_id'];

    // Initialize draft settings (will be loaded separately)
    _loadDraftSettings();

    // Initialize roster positions from league data
    _rosterPositions = {
      'QB': 0,
      'RB': 0,
      'WR': 0,
      'TE': 0,
      'FLEX': 0,
      'SUPER_FLEX': 0,
      'K': 0,
      'DEF': 0,
      'DL': 0,
      'LB': 0,
      'DB': 0,
      'IDP_FLEX': 0,
      'BN': 0,
    };

    // Load existing roster positions if available
    if (widget.league.rosterPositions != null) {
      for (var position in widget.league.rosterPositions!) {
        final posKey = position['position'] as String;
        final count = position['count'] as int;
        if (_rosterPositions.containsKey(posKey)) {
          _rosterPositions[posKey] = count;
        }
      }
    }

    // Initialize scoring settings controllers
    _passingTouchdownsController = TextEditingController(
        text: (_scoringSettings['passing_touchdowns'] ?? 4).toString());
    _passingYardsController = TextEditingController(
        text: (_scoringSettings['passing_yards'] ?? 0.04).toString());
    _rushingTouchdownsController = TextEditingController(
        text: (_scoringSettings['rushing_touchdowns'] ?? 6).toString());
    _rushingYardsController = TextEditingController(
        text: (_scoringSettings['rushing_yards'] ?? 0.1).toString());
    _receivingTouchdownsController = TextEditingController(
        text: (_scoringSettings['receiving_touchdowns'] ?? 6).toString());
    _receivingYardsController = TextEditingController(
        text: (_scoringSettings['receiving_yards'] ?? 0.1).toString());
    _receivingReceptionsController = TextEditingController(
        text: (_scoringSettings['receiving_receptions'] ?? 1).toString());
  }

  Future<void> _loadDraftSettings() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    await draftProvider.loadDraftByLeague(widget.league.id);

    if (mounted && draftProvider.currentDraft != null) {
      setState(() {
        _draftType = draftProvider.currentDraft!.draftType;
        _thirdRoundReversal = draftProvider.currentDraft!.thirdRoundReversal;
        _pickTimeSeconds = draftProvider.currentDraft!.pickTimeSeconds;
        _draftRounds = draftProvider.currentDraft!.rounds;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passingTouchdownsController.dispose();
    _passingYardsController.dispose();
    _rushingTouchdownsController.dispose();
    _rushingYardsController.dispose();
    _receivingTouchdownsController.dispose();
    _receivingYardsController.dispose();
    _receivingReceptionsController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveChanges() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('League name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    // Build scoring settings from controllers
    Map<String, dynamic>? updatedScoringSettings = {
      'passing_touchdowns':
          double.tryParse(_passingTouchdownsController.text) ?? 4,
      'passing_yards': double.tryParse(_passingYardsController.text) ?? 0.04,
      'rushing_touchdowns':
          double.tryParse(_rushingTouchdownsController.text) ?? 6,
      'rushing_yards': double.tryParse(_rushingYardsController.text) ?? 0.1,
      'receiving_touchdowns':
          double.tryParse(_receivingTouchdownsController.text) ?? 6,
      'receiving_yards': double.tryParse(_receivingYardsController.text) ?? 0.1,
      'receiving_receptions':
          double.tryParse(_receivingReceptionsController.text) ?? 1,
    };

    // Convert roster positions map to list format for backend
    final rosterPositionsList = _rosterPositions.entries
        .where(
            (entry) => entry.value > 0) // Only include positions with count > 0
        .map((entry) => {
              'position': entry.key,
              'count': entry.value,
            })
        .toList();

    final success = await leagueProvider.updateLeagueSettings(
      token: authProvider.token!,
      leagueId: widget.league.id,
      name: _nameController.text.trim(),
      seasonType: _seasonType,
      totalRosters: _totalRosters,
      settings: {
        'is_public': _isPublic,
        'start_week': _startWeek,
        'end_week': _endWeek,
        'playoff_week_start': _playoffWeekStart,
      },
      scoringSettings: updatedScoringSettings,
      rosterPositions: rosterPositionsList,
    );

    if (mounted) {
      if (success) {
        // Update draft settings if draft exists
        final draftProvider = Provider.of<DraftProvider>(context, listen: false);
        if (draftProvider.currentDraft != null) {
          final draftSuccess = await DraftService().updateDraftSettings(
            token: authProvider.token!,
            draftId: draftProvider.currentDraft!.id,
            draftType: _draftType,
            thirdRoundReversal: _thirdRoundReversal,
            pickTimeSeconds: _pickTimeSeconds,
            rounds: _draftRounds,
          );

          // Only show draft error if update actually failed (don't show for league-only updates)
          if (draftSuccess == null) {
            print('Draft settings update failed, but league settings updated successfully');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('League updated successfully!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(leagueProvider.errorMessage ?? 'Failed to update league'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCreateDraft() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null) return;

    final draft = await DraftService().createDraft(
      token: authProvider.token!,
      leagueId: widget.league.id,
      draftType: _draftType,
      thirdRoundReversal: _thirdRoundReversal,
      pickTimeSeconds: _pickTimeSeconds,
      rounds: _draftRounds,
    );

    if (draft != null && mounted) {
      // Reload draft provider
      await draftProvider.loadDraftByLeague(widget.league.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        // Trigger rebuild to show draft settings
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create draft'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _randomizeDraftOrder() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null || draftProvider.currentDraft == null) {
      return;
    }

    final success = await draftProvider.setDraftOrder(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
      randomize: true,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft order randomized!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to randomize draft order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleResetLeague() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset League'),
        content: const Text(
          'Are you sure you want to reset the league to pre-draft status?\n\n'
          'This will:\n'
          '• Delete the draft and all picks\n'
          '• Remove all players from all rosters\n'
          '• Keep all teams intact\n'
          '• Set league status to pre-draft\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset League'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isResetting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);

    if (authProvider.token == null) {
      setState(() => _isResetting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
      }
      return;
    }

    final success = await LeagueService().resetLeague(
      token: authProvider.token!,
      leagueId: widget.league.id,
    );

    if (mounted) {
      setState(() => _isResetting = false);

      if (success) {
        // Reload league data
        await leagueProvider.loadLeagueDetails(widget.league.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('League reset to pre-draft status successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to league details
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reset league'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTransferConfirmation(
    BuildContext context,
    Roster roster,
    LeagueProvider leagueProvider,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Commissioner Role'),
        content: Text(
          'Are you sure you want to transfer the commissioner role to ${roster.username}?\n\nYou will no longer be the commissioner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              if (authProvider.token != null) {
                final success = await leagueProvider.transferCommissioner(
                  token: authProvider.token!,
                  leagueId: widget.league.id,
                  newCommissionerId: roster.userId,
                );

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Commissioner role transferred to ${roster.username}',
                        ),
                      ),
                    );
                    // Reload league data to refresh the page
                    await leagueProvider.loadLeagueDetails(widget.league.id);
                    if (mounted) {
                      Navigator.of(context).pop(); // Close edit screen
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          leagueProvider.errorMessage ??
                              'Failed to transfer commissioner',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit League'),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // League icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sports_football,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Section 1: Basic Settings
                Text(
                  'Basic Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // League name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'League Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 16),

                // Total rosters
                DropdownButtonFormField<int>(
                  value: _totalRosters,
                  decoration: const InputDecoration(
                    labelText: 'Number of Teams',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: [
                    for (int i = 4; i <= 16; i += 2)
                      DropdownMenuItem(value: i, child: Text('$i Teams')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _totalRosters = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Season type
                DropdownButtonFormField<String>(
                  value: _seasonType,
                  decoration: const InputDecoration(
                    labelText: 'Season Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pre',
                      child: Text('Preseason'),
                    ),
                    DropdownMenuItem(
                      value: 'regular',
                      child: Text('Regular Season'),
                    ),
                    DropdownMenuItem(
                      value: 'post',
                      child: Text('Postseason'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _seasonType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Start week
                DropdownButtonFormField<int>(
                  value: _startWeek,
                  decoration: const InputDecoration(
                    labelText: 'Start Week',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.play_arrow),
                    helperText: 'Week the season starts',
                  ),
                  items: [
                    for (int i = 1; i <= 17; i++)
                      DropdownMenuItem(value: i, child: Text('Week $i')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _startWeek = value!;
                      // Ensure end week is not before start week
                      if (_endWeek < _startWeek) {
                        _endWeek = _startWeek;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // End week
                DropdownButtonFormField<int>(
                  value: _endWeek,
                  decoration: const InputDecoration(
                    labelText: 'End Week',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.stop),
                    helperText: 'Week the season ends',
                  ),
                  items: [
                    for (int i = _startWeek; i <= 17; i++)
                      DropdownMenuItem(value: i, child: Text('Week $i')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _endWeek = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Playoff week start
                DropdownButtonFormField<int>(
                  value: _playoffWeekStart,
                  decoration: const InputDecoration(
                    labelText: 'Playoff Week Start',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.emoji_events),
                    helperText: 'Week when playoffs begin',
                  ),
                  items: [
                    for (int i = _startWeek + 1; i <= 18; i++)
                      DropdownMenuItem(value: i, child: Text('Week $i')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _playoffWeekStart = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Public/Private toggle
                Card(
                  child: SwitchListTile(
                    title: const Text('Public League'),
                    subtitle: Text(
                      _isPublic
                          ? 'Anyone can find and join this league'
                          : 'Invite-only league',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                    secondary: Icon(
                      _isPublic ? Icons.public : Icons.lock,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Section 2: Scoring Settings (Collapsible)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      'Scoring Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: const Text('Configure points for each stat'),
                    initiallyExpanded: false,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Passing Touchdowns
                            TextFormField(
                              controller: _passingTouchdownsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Passing Touchdowns',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports),
                                helperText: 'Points per passing TD',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Passing Yards
                            TextFormField(
                              controller: _passingYardsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Passing Yards',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports),
                                helperText: 'Points per passing yard',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Rushing Touchdowns
                            TextFormField(
                              controller: _rushingTouchdownsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Rushing Touchdowns',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports),
                                helperText: 'Points per rushing TD',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Rushing Yards
                            TextFormField(
                              controller: _rushingYardsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Rushing Yards',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports),
                                helperText: 'Points per rushing yard',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Receiving Touchdowns
                            TextFormField(
                              controller: _receivingTouchdownsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Receiving Touchdowns',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports),
                                helperText: 'Points per receiving TD',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Receiving Yards
                            TextFormField(
                              controller: _receivingYardsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Receiving Yards',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports),
                                helperText: 'Points per receiving yard',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Receiving Receptions
                            TextFormField(
                              controller: _receivingReceptionsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Receiving Receptions',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports),
                                helperText: 'Points per reception',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 3: Roster Positions (Collapsible)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      'Roster Positions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: const Text('Set lineup positions and bench size'),
                    initiallyExpanded: false,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Offensive Positions
                            Text(
                              'Offense',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildRosterPositionRow('QB', 'Quarterback'),
                            _buildRosterPositionRow('RB', 'Running Back'),
                            _buildRosterPositionRow('WR', 'Wide Receiver'),
                            _buildRosterPositionRow('TE', 'Tight End'),
                            _buildRosterPositionRow('FLEX', 'Flex (RB/WR/TE)'),
                            _buildRosterPositionRow(
                                'SUPER_FLEX', 'Super Flex (QB/RB/WR/TE)'),
                            const SizedBox(height: 16),

                            // Special Teams
                            Text(
                              'Special Teams',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildRosterPositionRow('K', 'Kicker'),
                            _buildRosterPositionRow('DEF', 'Team Defense'),
                            const SizedBox(height: 16),

                            // IDP Positions
                            Text(
                              'IDP (Individual Defensive Players)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildRosterPositionRow('DL', 'Defensive Line'),
                            _buildRosterPositionRow('LB', 'Linebacker'),
                            _buildRosterPositionRow('DB', 'Defensive Back'),
                            _buildRosterPositionRow('IDP_FLEX', 'IDP Flex'),
                            const SizedBox(height: 16),

                            // Bench
                            Text(
                              'Bench',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildRosterPositionRow('BN', 'Bench'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 4: Draft Settings (Collapsible)
                Consumer<DraftProvider>(
                  builder: (context, draftProvider, child) {
                    final hasDraft = draftProvider.currentDraft != null;

                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          'Draft Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        subtitle: Text(
                          hasDraft
                            ? 'Configure draft type and timer'
                            : 'Create a draft to configure settings'
                        ),
                        initiallyExpanded: false,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                            // Draft Type
                            DropdownButtonFormField<String>(
                              value: _draftType,
                              decoration: const InputDecoration(
                                labelText: 'Draft Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.swap_vert),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'snake',
                                  child: Text('Snake Draft'),
                                ),
                                DropdownMenuItem(
                                  value: 'linear',
                                  child: Text('Linear Draft'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _draftType = value!);
                              },
                            ),
                            const SizedBox(height: 12),

                            // Third Round Reversal (only for snake)
                            if (_draftType == 'snake')
                              SwitchListTile(
                                title: const Text('3rd Round Reversal'),
                                subtitle: const Text(
                                    'Reverse order in 3rd round (like NFL)'),
                                value: _thirdRoundReversal,
                                onChanged: (value) {
                                  setState(() => _thirdRoundReversal = value);
                                },
                              ),
                            const SizedBox(height: 12),

                            // Pick Time
                            DropdownButtonFormField<int>(
                              value: _pickTimeSeconds,
                              decoration: const InputDecoration(
                                labelText: 'Pick Timer',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer),
                                helperText: 'Seconds per pick',
                              ),
                              items: const [
                                DropdownMenuItem(value: 10, child: Text('10 seconds')),
                                DropdownMenuItem(value: 30, child: Text('30 seconds')),
                                DropdownMenuItem(value: 60, child: Text('1 minute')),
                                DropdownMenuItem(value: 90, child: Text('1.5 minutes')),
                                DropdownMenuItem(value: 120, child: Text('2 minutes')),
                                DropdownMenuItem(value: 180, child: Text('3 minutes')),
                                DropdownMenuItem(value: 300, child: Text('5 minutes')),
                              ],
                              onChanged: (value) {
                                setState(() => _pickTimeSeconds = value!);
                              },
                            ),
                            const SizedBox(height: 12),

                            // Draft Rounds
                            DropdownButtonFormField<int>(
                              value: _draftRounds,
                              decoration: const InputDecoration(
                                labelText: 'Number of Rounds',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.format_list_numbered),
                              ),
                              items: List.generate(
                                20,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('${index + 1} rounds'),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() => _draftRounds = value!);
                              },
                            ),
                            const SizedBox(height: 24),

                            // Create Draft Button (only show if no draft exists)
                            if (!hasDraft)
                              FilledButton.icon(
                                onPressed: _handleCreateDraft,
                                icon: const Icon(Icons.add_circle),
                                label: const Text('Create Draft with These Settings'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  backgroundColor: Colors.green,
                                ),
                              ),

                            // Draft Order Section (only show if draft exists and not started)
                            if (hasDraft && draftProvider.currentDraft!.status == 'not_started') ...[
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Draft Order',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  FilledButton.icon(
                                    onPressed: _randomizeDraftOrder,
                                    icon: const Icon(Icons.shuffle),
                                    label: Text(
                                      draftProvider.draftOrder.isEmpty
                                          ? 'Randomize'
                                          : 'Re-randomize'
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Draft order list
                              if (draftProvider.draftOrder.isNotEmpty)
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 300),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: draftProvider.draftOrder.length,
                                    itemBuilder: (context, index) {
                                      final order = draftProvider.draftOrder[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          child: Text('${order.draftPosition}'),
                                        ),
                                        title: Text(order.displayName),
                                        subtitle: Text('Team ${order.rosterNumber ?? "?"}'),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.shuffle,
                                        size: 48,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No draft order set',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Click "Randomize" to set the draft order',
                                        style: Theme.of(context).textTheme.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Section 5: Commissioner Settings (Collapsible)
                Consumer<LeagueProvider>(
                  builder: (context, leagueProvider, child) {
                    final rosters = leagueProvider.selectedLeagueRosters;
                    final authProvider =
                        Provider.of<AuthProvider>(context, listen: false);

                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          'Commissioner Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        subtitle: const Text('Transfer commissioner role'),
                        initiallyExpanded: false,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transfer Commissioner',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Transfer your commissioner role to another league member',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Members list for transfer
                                if (rosters.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: Text(
                                        'No other members in league',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: rosters.length,
                                    itemBuilder: (context, index) {
                                      final roster = rosters[index];
                                      final currentUserId = authProvider.user?.id;

                                      // Skip current user
                                      if (roster.userId == currentUserId) {
                                        return const SizedBox.shrink();
                                      }

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            child: Text(
                                              'R${roster.rosterId}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            roster.username ?? 'Unknown User',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Text(roster.email ?? ''),
                                          trailing: ElevatedButton.icon(
                                            onPressed: () {
                                              _showTransferConfirmation(
                                                context,
                                                roster,
                                                leagueProvider,
                                                authProvider,
                                              );
                                            },
                                            icon: const Icon(Icons.person,
                                                size: 16),
                                            label: const Text('Transfer'),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Info message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Note: As the commissioner, you can edit league settings. Some settings may be locked once the season starts.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                Consumer<LeagueProvider>(
                  builder: (context, leagueProvider, child) {
                    return ElevatedButton(
                      onPressed: leagueProvider.status == LeagueStatus.loading
                          ? null
                          : _handleSaveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: leagueProvider.status == LeagueStatus.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16),
                            ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Reset League button (Commissioner only)
                OutlinedButton(
                  onPressed: _isResetting ? null : _handleResetLeague,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: _isResetting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.restart_alt),
                            SizedBox(width: 8),
                            Text(
                              'Reset League',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRosterPositionRow(String positionKey, String positionName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              positionName,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              value: _rosterPositions[positionKey],
              decoration: InputDecoration(
                labelText: 'Count',
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                for (int i = 0; i <= 6; i++)
                  DropdownMenuItem(value: i, child: Text('$i')),
              ],
              onChanged: (value) {
                setState(() {
                  _rosterPositions[positionKey] = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
