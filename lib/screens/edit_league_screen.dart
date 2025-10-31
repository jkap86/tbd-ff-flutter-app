import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../providers/draft_provider.dart';
import '../providers/matchup_provider.dart';
import '../models/league_model.dart';
import '../models/roster_model.dart';
import '../services/draft_service.dart';
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
    _tradeDetailsSetting = widget.league.tradeDetailsSetting;

    // Initialize draft settings (will be loaded separately)
    _loadDraftSettings();

    // Load waiver settings
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

  Future<void> _loadDraftSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null) return;

    await draftProvider.loadDraftByLeague(authProvider.token!, widget.league.id);

    if (mounted && draftProvider.currentDraft != null) {
      final draft = draftProvider.currentDraft!;
      setState(() {
        _draftType = draft.draftType;
        _thirdRoundReversal = draft.thirdRoundReversal;
        _pickTimeSeconds = draft.pickTimeSeconds;
        _draftRounds = draft.rounds;
        _timerMode = draft.timerMode;
        _teamTimeBudgetMinutes = draft.teamTimeBudgetSeconds != null
            ? (draft.teamTimeBudgetSeconds! / 60).round()
            : 60;

        // Load auction-specific settings
        _startingBudget = draft.startingBudget;
        _minBid = draft.minBid;
        _nominationsPerManager = draft.nominationsPerManager;
        _nominationTimerHours = draft.nominationTimerHours ?? 24;
        _reserveBudgetPerSlot = draft.reserveBudgetPerSlot;

        // Load overnight pause settings (stored in UTC, convert to local)
        final settings = draft.settings;
        if (settings != null) {
          _autoPauseEnabled = settings['auto_pause_enabled'] == true;
          if (_autoPauseEnabled) {
            final startHourUTC = settings['auto_pause_start_hour'] ?? 23;
            final startMinuteUTC = settings['auto_pause_start_minute'] ?? 0;
            final endHourUTC = settings['auto_pause_end_hour'] ?? 8;
            final endMinuteUTC = settings['auto_pause_end_minute'] ?? 0;

            // Convert UTC to local time
            _autoPauseStartTime = _utcToLocalTimeOfDay(startHourUTC, startMinuteUTC);
            _autoPauseEndTime = _utcToLocalTimeOfDay(endHourUTC, endMinuteUTC);
          }
        }
      });
    }
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

                // Section 4: Waiver Settings (Collapsible) - moved from Section 5
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
                                    value: 'waiver',
                                    child: Text('Waiver Priority'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'free_agent',
                                    child: Text('Free Agent (First Come)'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _waiverType = value!);
                                },
                              ),
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
