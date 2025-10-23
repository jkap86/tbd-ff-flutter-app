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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.league.name);
    _isPublic = widget.league.settings?['is_public'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
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

    final success = await leagueProvider.updateLeagueSettings(
      token: authProvider.token!,
      leagueId: widget.league.id,
      name: _nameController.text.trim(),
      settings: {
        'is_public': _isPublic,
      },
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

                // Info message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Note: As the commissioner, you can edit the league name and privacy settings. Other league settings cannot be changed after creation.',
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
