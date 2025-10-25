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
  int _totalRosters = 12;
  bool _isPublic = false;

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
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

      final success = await leagueProvider.createLeague(
        token: authProvider.token!,
        name: _nameController.text.trim(),
        season: _seasonController.text.trim(),
        leagueType: _leagueType,
        totalRosters: _totalRosters,
        settings: {
          'is_public': _isPublic,
        },
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
      appBar: AppBar(
        title: const Text('Create League'),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
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

                  // League type - WITH DESCRIPTIONS
                  DropdownButtonFormField<String>(
                    value: _leagueType,
                    decoration: const InputDecoration(
                      labelText: 'League Format',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'redraft',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Redraft'),
                            Text(
                              'Start fresh each season',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'keeper',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Keeper'),
                            Text(
                              'Keep a few players yearly',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'dynasty',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Dynasty'),
                            Text(
                              'Keep most players long-term',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'betting',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Betting'),
                            Text(
                              'Vegas-style betting format',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _leagueType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // League type info
                  _buildLeagueTypeInfo(),
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

  Widget _buildLeagueTypeInfo() {
    String description;
    IconData icon;
    Color color;

    switch (_leagueType) {
      case 'redraft':
        description =
            'All players return to the draft pool each season. Perfect for casual leagues.';
        icon = Icons.refresh;
        color = Colors.blue;
        break;
      case 'keeper':
        description =
            'Keep a small number of players (typically 1-3) each season while drafting new ones.';
        icon = Icons.person;
        color = Colors.orange;
        break;
      case 'dynasty':
        description =
            'Keep most or all of your roster year to year. Emphasizes long-term team building.';
        icon = Icons.trending_up;
        color = Colors.purple;
        break;
      case 'betting':
        description =
            'Vegas-style betting format. Teams start with money and place bets. No scoring required.';
        icon = Icons.money;
        color = Colors.red;
        break;
      default:
        description = '';
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
