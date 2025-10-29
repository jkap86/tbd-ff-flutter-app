import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../widgets/responsive_container.dart';

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _seasonController =
      TextEditingController(text: DateTime.now().year.toString());

  String _leagueType = 'redraft';
  String _seasonType = 'regular';
  int _totalRosters = 12;
  int _startWeek = 1;
  int _endWeek = 17;
  int _playoffWeekStart = 15;
  bool _isPublic = false;

  // Roster positions with default values
  final Map<String, int> _rosterPositions = {
    'QB': 1,
    'RB': 2,
    'WR': 3,
    'TE': 1,
    'FLEX': 3,
    'SUPER_FLEX': 1,
    'K': 0,
    'DEF': 0,
    'DL': 0,
    'LB': 0,
    'DB': 0,
    'IDP_FLEX': 0,
    'BN': 6,
  };

  // Scoring settings controllers
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
    // Initialize scoring settings with default values
    _passingTouchdownsController = TextEditingController(text: '4');
    _passingYardsController = TextEditingController(text: '0.04');
    _rushingTouchdownsController = TextEditingController(text: '6');
    _rushingYardsController = TextEditingController(text: '0.1');
    _receivingTouchdownsController = TextEditingController(text: '6');
    _receivingYardsController = TextEditingController(text: '0.1');
    _receivingReceptionsController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
    _passingTouchdownsController.dispose();
    _passingYardsController.dispose();
    _rushingTouchdownsController.dispose();
    _rushingYardsController.dispose();
    _receivingTouchdownsController.dispose();
    _receivingYardsController.dispose();
    _receivingReceptionsController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateLeague() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final leagueProvider =
          Provider.of<LeagueProvider>(context, listen: false);

      if (authProvider.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
        return;
      }

      // Convert roster positions map to list format for backend
      final rosterPositionsList = _rosterPositions.entries
          .where((entry) => entry.value > 0) // Only include positions with count > 0
          .map((entry) => {
                'position': entry.key,
                'count': entry.value,
              })
          .toList();

      final success = await leagueProvider.createLeague(
        token: authProvider.token!,
        name: _nameController.text.trim(),
        season: _seasonController.text.trim(),
        seasonType: _seasonType,
        leagueType: _leagueType,
        totalRosters: _totalRosters,
        settings: {
          'is_public': _isPublic,
          'start_week': _startWeek,
          'end_week': _endWeek,
          'playoff_week_start': _playoffWeekStart,
        },
        scoringSettings: {
          'passing_touchdowns':
              double.tryParse(_passingTouchdownsController.text) ?? 4,
          'passing_yards':
              double.tryParse(_passingYardsController.text) ?? 0.04,
          'rushing_touchdowns':
              double.tryParse(_rushingTouchdownsController.text) ?? 6,
          'rushing_yards':
              double.tryParse(_rushingYardsController.text) ?? 0.1,
          'receiving_touchdowns':
              double.tryParse(_receivingTouchdownsController.text) ?? 6,
          'receiving_yards':
              double.tryParse(_receivingYardsController.text) ?? 0.1,
          'receiving_receptions':
              double.tryParse(_receivingReceptionsController.text) ?? 1,
        },
        rosterPositions: rosterPositionsList,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('League created successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  leagueProvider.errorMessage ?? 'Failed to create league'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Create League'),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: Form(
              key: _formKey,
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

                  // League name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'League Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a league name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Season
                  TextFormField(
                    controller: _seasonController,
                    decoration: const InputDecoration(
                      labelText: 'Season',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      helperText: 'e.g., 2024, 2025',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a season';
                      }
                      final year = int.tryParse(value);
                      if (year == null || year < 2020 || year > 2100) {
                        return 'Please enter a valid year';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // League type
                  DropdownButtonFormField<String>(
                    value: _leagueType,
                    decoration: const InputDecoration(
                      labelText: 'League Format',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                      helperText: 'Only Redraft is currently available',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'redraft',
                        child: Text('Redraft'),
                      ),
                      DropdownMenuItem(
                        value: 'keeper',
                        enabled: false,
                        child: Text('Keeper (Coming Soon)'),
                      ),
                      DropdownMenuItem(
                        value: 'dynasty',
                        enabled: false,
                        child: Text('Dynasty (Coming Soon)'),
                      ),
                      DropdownMenuItem(
                        value: 'devy',
                        enabled: false,
                        child: Text('Devy (Coming Soon)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _leagueType = value!;
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

                  // Scoring Settings Section (Collapsible)
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

                  // Roster Positions Section (Collapsible)
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
                              _buildRosterPositionRow('SUPER_FLEX', 'Super Flex (QB/RB/WR/TE)'),
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
                  const SizedBox(height: 32),

                  // Create button
                  Consumer<LeagueProvider>(
                    builder: (context, leagueProvider, child) {
                      return ElevatedButton(
                        onPressed: leagueProvider.status == LeagueStatus.loading
                            ? null
                            : _handleCreateLeague,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: leagueProvider.status == LeagueStatus.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Create League',
                                style: TextStyle(fontSize: 16),
                              ),
                      );
                    },
                  ),
                ],
              ),
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
