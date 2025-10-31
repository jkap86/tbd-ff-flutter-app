import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../providers/matchup_provider.dart';
import '../models/league_model.dart';
import '../models/roster_model.dart';
import '../services/league_service.dart';
import '../services/league_median_service.dart';
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



  // Waiver settings
  String _waiverType = 'faab';
  int _faabBudget = 100;
  int _waiverPeriodDays = 2;
  String _processSchedule = 'daily';
  bool _isLoadingWaiverSettings = false;

  // Trade notification settings
  String _tradeNotificationSetting = 'proposer_choice';
  String _tradeDetailsSetting = 'proposer_choice';

  // League median settings
  bool _enableLeagueMedian = false;
  int? _medianMatchupWeekStart;
  int? _medianMatchupWeekEnd;
  bool _isLoadingMedianSettings = false;

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

    // Initialize trade notification settings
    _tradeNotificationSetting = widget.league.tradeNotificationSetting;
    _tradeDetailsSetting = widget.league.tradeDetailsSetting;    // Load waiver settings
    _loadWaiverSettings();

    // Load league median settings
    _loadLeagueMedianSettings();

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

  

  Future<void> _loadWaiverSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    setState(() {
      _isLoadingWaiverSettings = true;
    });

    final settings = await LeagueService().getWaiverSettings(
      token: authProvider.token!,
      leagueId: widget.league.id,
    );

    if (mounted && settings != null) {
      setState(() {
        _waiverType = settings.waiverType;
        _faabBudget = settings.faabBudget;
        _waiverPeriodDays = settings.waiverPeriodDays;
        _processSchedule = settings.processSchedule;
        _isLoadingWaiverSettings = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingWaiverSettings = false;
      });
    }
  }

  Future<void> _loadLeagueMedianSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    setState(() {
      _isLoadingMedianSettings = true;
    });

    final settings = await LeagueMedianService.getLeagueMedianSettings(
      authProvider.token!,
      widget.league.id,
    );

    if (mounted && settings != null) {
      setState(() {
        _enableLeagueMedian = settings.enableLeagueMedian;
        _medianMatchupWeekStart = settings.medianMatchupWeekStart;
        _medianMatchupWeekEnd = settings.medianMatchupWeekEnd;
        _isLoadingMedianSettings = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingMedianSettings = false;
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

  Future<void> _handleSaveWaiverSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    final updatedSettings = await LeagueService().updateWaiverSettings(
      token: authProvider.token!,
      leagueId: widget.league.id,
      waiverType: _waiverType,
      faabBudget: _faabBudget,
      waiverPeriodDays: _waiverPeriodDays,
      processSchedule: _processSchedule,
    );

    if (mounted) {
      if (updatedSettings != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waiver settings updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update waiver settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLeagueMedianSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    // Validate week range
    if (_enableLeagueMedian) {
      if (_medianMatchupWeekStart == null || _medianMatchupWeekEnd == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set both start and end weeks'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_medianMatchupWeekEnd! < _medianMatchupWeekStart!) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End week must be greater than or equal to start week'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final result = await LeagueMedianService.updateLeagueMedianSettings(
      authProvider.token!,
      widget.league.id,
      enableLeagueMedian: _enableLeagueMedian,
      medianMatchupWeekStart: _medianMatchupWeekStart,
      medianMatchupWeekEnd: _medianMatchupWeekEnd,
    );

    if (mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('League median settings updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update league median settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateMedianMatchups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    final result = await LeagueMedianService.generateMedianMatchups(
      authProvider.token!,
      widget.league.id,
      widget.league.season,
    );

    if (mounted) {
      if (result != null) {
        final matchupsCreated = result['matchups_created'] ?? 0;
        final weeksGenerated = result['weeks_generated'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Generated $matchupsCreated median matchups for $weeksGenerated weeks',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate median matchups'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

    // Show success message and navigate back immediately
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving changes in background...')),
    );
    Navigator.of(context).pop();

    // Do all the work in background (non-blocking)
    _saveAllChangesInBackground(
      authProvider.token!,
      leagueProvider,
      widget.league.id,
      _nameController.text.trim(),
      _seasonType,
      _totalRosters,
      {
        'is_public': _isPublic,
        'start_week': _startWeek,
        'end_week': _endWeek,
        'playoff_week_start': _playoffWeekStart,
      },
      updatedScoringSettings,
      rosterPositionsList,
      widget.league.season,
      _startWeek,
      _playoffWeekStart,
    );
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
        await leagueProvider.loadLeagueDetails(authProvider.token!, widget.league.id);

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
                    await leagueProvider.loadLeagueDetails(authProvider.token!, widget.league.id);
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
                    title: Text(_isPublic ? 'Public League' : 'Private League'),
                    subtitle: Text(
                      _isPublic
                          ? 'Anyone can find and join this league'
                          : 'Private - Invite only',
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

                // Section 5: Waiver Settings (Collapsible)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      'Waiver & Free Agent Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: const Text('Configure waivers and free agents'),
                    initiallyExpanded: false,
                    children: [
                      if (_isLoadingWaiverSettings)
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Waiver Type
                              DropdownButtonFormField<String>(
                                value: _waiverType,
                                decoration: const InputDecoration(
                                  labelText: 'Waiver Type',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.gavel),
                                  helperText: 'How players are claimed',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'faab',
                                    child: Text('FAAB (Blind Bidding)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rolling',
                                    child: Text('Rolling Waivers'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'none',
                                    child: Text('Free Agents Only'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _waiverType = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // FAAB Budget (only show if FAAB type)
                              if (_waiverType == 'faab') ...[
                                TextFormField(
                                  initialValue: _faabBudget.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'FAAB Budget',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                    helperText: 'Starting budget for each team',
                                  ),
                                  onChanged: (value) {
                                    final budget = int.tryParse(value);
                                    if (budget != null && budget >= 0) {
                                      setState(() {
                                        _faabBudget = budget;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Waiver Period Days
                              DropdownButtonFormField<int>(
                                value: _waiverPeriodDays,
                                decoration: const InputDecoration(
                                  labelText: 'Waiver Period',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.timer),
                                  helperText: 'Days before players become free agents',
                                ),
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('No Wait (Instant FA)')),
                                  DropdownMenuItem(value: 1, child: Text('1 Day')),
                                  DropdownMenuItem(value: 2, child: Text('2 Days')),
                                  DropdownMenuItem(value: 3, child: Text('3 Days')),
                                  DropdownMenuItem(value: 4, child: Text('4 Days')),
                                  DropdownMenuItem(value: 5, child: Text('5 Days')),
                                  DropdownMenuItem(value: 7, child: Text('1 Week')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _waiverPeriodDays = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Process Schedule
                              DropdownButtonFormField<String>(
                                value: _processSchedule,
                                decoration: const InputDecoration(
                                  labelText: 'Processing Schedule',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.schedule),
                                  helperText: 'When waivers are processed',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: Text('Daily (3:00 AM)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'twice_weekly',
                                    child: Text('Twice Weekly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: Text('Weekly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'manual',
                                    child: Text('Manual (Commissioner Only)'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _processSchedule = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 24),

                              // Info box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _waiverType == 'faab'
                                            ? 'Teams bid on players using their FAAB budget. Highest bid wins.'
                                            : _waiverType == 'rolling'
                                            ? 'Teams are assigned waiver priority. Lowest priority team gets first pick.'
                                            : 'All players are immediately available as free agents.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Save button
                              FilledButton.icon(
                                onPressed: _handleSaveWaiverSettings,
                                icon: const Icon(Icons.save),
                                label: const Text('Save Waiver Settings'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 6: Trade Notification Settings (Collapsible)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      'Trade Notification Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: const Text('Control trade proposal notifications'),
                    initiallyExpanded: false,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Notification setting
                            const Text(
                              'League Chat Notifications',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'always_off',
                                  label: Text('Always Off'),
                                  icon: Icon(Icons.notifications_off, size: 18),
                                ),
                                ButtonSegment(
                                  value: 'proposer_choice',
                                  label: Text('Proposer Choice'),
                                  icon: Icon(Icons.people, size: 18),
                                ),
                                ButtonSegment(
                                  value: 'always_on',
                                  label: Text('Always On'),
                                  icon: Icon(Icons.notifications_active, size: 18),
                                ),
                              ],
                              selected: {_tradeNotificationSetting},
                              onSelectionChanged: (Set<String> selection) {
                                setState(() {
                                  _tradeNotificationSetting = selection.first;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            // Details setting
                            const Text(
                              'Show Trade Details',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'always_off',
                                  label: Text('Always Off'),
                                  icon: Icon(Icons.visibility_off, size: 18),
                                ),
                                ButtonSegment(
                                  value: 'proposer_choice',
                                  label: Text('Proposer Choice'),
                                  icon: Icon(Icons.people, size: 18),
                                ),
                                ButtonSegment(
                                  value: 'always_on',
                                  label: Text('Always On'),
                                  icon: Icon(Icons.visibility, size: 18),
                                ),
                              ],
                              selected: {_tradeDetailsSetting},
                              onSelectionChanged: (Set<String> selection) {
                                setState(() {
                                  _tradeDetailsSetting = selection.first;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            // Info text
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'About These Settings:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '• Always Off: Trade proposals will never post to league chat',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• Proposer Choice: Trade proposer can choose whether to notify (default)',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• Always On: Trade proposals will always post to league chat',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 7: League Median Settings (Collapsible)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      'League Median Scoring',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: const Text('Configure median matchups'),
                    initiallyExpanded: false,
                    children: [
                      if (_isLoadingMedianSettings)
                        const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Enable/Disable Toggle
                              Card(
                                child: SwitchListTile(
                                  title: const Text('Enable League Median Scoring'),
                                  subtitle: const Text(
                                    'Teams compete against opponent + league median each week',
                                  ),
                                  value: _enableLeagueMedian,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _enableLeagueMedian = value;
                                    });
                                  },
                                  secondary: Icon(
                                    _enableLeagueMedian ? Icons.check_circle : Icons.circle_outlined,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Week Range Pickers (only shown if enabled)
                              if (_enableLeagueMedian) ...[
                                ListTile(
                                  title: const Text('Median Matchup Start Week'),
                                  trailing: DropdownButton<int>(
                                    value: _medianMatchupWeekStart,
                                    hint: const Text('Select Week'),
                                    items: List.generate(18, (i) => i + 1).map((week) {
                                      return DropdownMenuItem(
                                        value: week,
                                        child: Text('Week $week'),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _medianMatchupWeekStart = value;
                                        // Ensure end week is not before start week
                                        if (_medianMatchupWeekEnd != null &&
                                            _medianMatchupWeekEnd! < value!) {
                                          _medianMatchupWeekEnd = value;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Median Matchup End Week'),
                                  trailing: DropdownButton<int>(
                                    value: _medianMatchupWeekEnd,
                                    hint: const Text('Select Week'),
                                    items: List.generate(18, (i) => i + 1)
                                        .where((week) =>
                                          _medianMatchupWeekStart == null ||
                                          week >= _medianMatchupWeekStart!)
                                        .map((week) {
                                      return DropdownMenuItem(
                                        value: week,
                                        child: Text('Week $week'),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _medianMatchupWeekEnd = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Generate Matchups Button (commissioner only)
                                Consumer<AuthProvider>(
                                  builder: (context, authProvider, child) {
                                    final isCommissioner = widget.league.isUserCommissioner(
                                      authProvider.user?.id ?? 0,
                                    );

                                    if (!isCommissioner) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: _generateMedianMatchups,
                                          icon: const Icon(Icons.auto_awesome),
                                          label: const Text('Generate Median Matchups'),
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size.fromHeight(48),
                                            backgroundColor: Theme.of(context).colorScheme.tertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'This will create median matchups for all weeks in the configured range',
                                          style: Theme.of(context).textTheme.bodySmall,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    );
                                  },
                                ),
                              ],

                              // Info box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _enableLeagueMedian
                                            ? 'Each team gets 2 matchups per week: one against an opponent and one against the league median score.'
                                            : 'Enable League Median to give teams an additional matchup against the league median score each week.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Save button
                              FilledButton.icon(
                                onPressed: _saveLeagueMedianSettings,
                                icon: const Icon(Icons.save),
                                label: const Text('Save League Median Settings'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 8: Commissioner Settings (Collapsible)
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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

  /// Convert UTC time to local TimeOfDay
  

  /// Convert local TimeOfDay to UTC
  

  /// Save all changes in background (non-blocking)
  void _saveAllChangesInBackground(
    String token,
    LeagueProvider leagueProvider,
    int leagueId,
    String name,
    String seasonType,
    int totalRosters,
    Map<String, dynamic> settings,
    Map<String, dynamic> scoringSettings,
    List<Map<String, dynamic>> rosterPositions,
    String season,
    int startWeek,
    int playoffWeekStart,
  ) async {
    debugPrint('[EditLeague] Starting background save...');

    // Step 1: Update league settings
    final success = await leagueProvider.updateLeagueSettings(
      token: token,
      leagueId: leagueId,
      name: name,
      seasonType: seasonType,
      totalRosters: totalRosters,
      settings: settings,
      scoringSettings: scoringSettings,
      rosterPositions: rosterPositions,
      tradeNotificationSetting: _tradeNotificationSetting,
      tradeDetailsSetting: _tradeDetailsSetting,
    );

    if (!success) {
      debugPrint('[EditLeague] Failed to update league settings');
      return;
    }

    debugPrint('[EditLeague] League settings updated');
    // Step 2: Generate matchups

    // Step 2: Generate matchups
    _generateMatchupsInBackground(
      token,
      leagueId,
      season,
      startWeek,
      playoffWeekStart,
    );
  }

  /// Generate matchups in background (non-blocking)
  void _generateMatchupsInBackground(
    String token,
    int leagueId,
    String season,
    int startWeek,
    int playoffWeekStart,
  ) async {
    debugPrint('[EditLeague] Auto-generating matchups for weeks $startWeek to ${playoffWeekStart - 1} in background...');

    // Check if widget is still mounted before using context
    if (!mounted) return;

    final matchupProvider = Provider.of<MatchupProvider>(context, listen: false);
    final totalWeeks = playoffWeekStart - startWeek;

    int successCount = 0;
    for (int week = startWeek; week < playoffWeekStart; week++) {
      final matchupSuccess = await matchupProvider.generateMatchups(
        token: token,
        leagueId: leagueId,
        week: week,
        season: season,
      );
      if (matchupSuccess) {
        successCount++;

        // Auto-calculate scores for this week
        debugPrint('[EditLeague] Calculating scores for week $week...');
        await matchupProvider.updateScores(
          token: token,
          leagueId: leagueId,
          week: week,
          season: season,
        );
      }
    }

    debugPrint('[EditLeague] Background matchup generation complete: $successCount/$totalWeeks weeks');
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
              decoration: const InputDecoration(
                labelText: 'Count',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
