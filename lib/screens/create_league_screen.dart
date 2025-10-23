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

  String _seasonType = 'regular';
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
        seasonType: _seasonType,
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

                  // Season type
                  DropdownButtonFormField<String>(
                    value: _seasonType,
                    decoration: const InputDecoration(
                      labelText: 'Season Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'regular', child: Text('Regular')),
                      DropdownMenuItem(
                          value: 'dynasty', child: Text('Dynasty')),
                      DropdownMenuItem(value: 'keeper', child: Text('Keeper')),
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
}
