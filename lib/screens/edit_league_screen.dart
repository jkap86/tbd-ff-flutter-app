import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/league_model.dart';
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
  late Map<String, dynamic> _scoringSettings;

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
    _scoringSettings = widget.league.scoringSettings ?? {};

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

    // Build scoring settings from controllers (only for non-betting leagues)
    Map<String, dynamic>? updatedScoringSettings;
    if (widget.league.seasonType != 'betting') {
      updatedScoringSettings = {
        'passing_touchdowns':
            double.tryParse(_passingTouchdownsController.text) ?? 4,
        'passing_yards': double.tryParse(_passingYardsController.text) ?? 0.04,
        'rushing_touchdowns':
            double.tryParse(_rushingTouchdownsController.text) ?? 6,
        'rushing_yards': double.tryParse(_rushingYardsController.text) ?? 0.1,
        'receiving_touchdowns':
            double.tryParse(_receivingTouchdownsController.text) ?? 6,
        'receiving_yards':
            double.tryParse(_receivingYardsController.text) ?? 0.1,
        'receiving_receptions':
            double.tryParse(_receivingReceptionsController.text) ?? 1,
      };
    }

    final success = await leagueProvider.updateLeagueSettings(
      token: authProvider.token!,
      leagueId: widget.league.id,
      name: _nameController.text.trim(),
      settings: {
        'is_public': _isPublic,
      },
      scoringSettings: updatedScoringSettings,
    );

    if (mounted) {
      if (success) {
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

                // Section 2: Scoring Settings (hidden for betting leagues)
                if (widget.league.seasonType != 'betting') ...[
                  Text(
                    'Scoring Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

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
                  const SizedBox(height: 24),
                ] else ...[
                  // Betting league message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Betting leagues do not use scoring settings. Teams compete using Vegas-style betting mechanics.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
