import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/roster_model.dart';
import '../widgets/responsive_container.dart';

class CommissionerSettingsScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;

  const CommissionerSettingsScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<CommissionerSettingsScreen> createState() =>
      _CommissionerSettingsScreenState();
}

class _CommissionerSettingsScreenState
    extends State<CommissionerSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadLeagueDetails();
  }

  Future<void> _loadLeagueDetails() async {
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
    await leagueProvider.loadLeagueDetails(widget.leagueId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commissioner Settings'),
      ),
      body: Consumer2<LeagueProvider, AuthProvider>(
        builder: (context, leagueProvider, authProvider, child) {
          if (leagueProvider.status == LeagueStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final league = leagueProvider.selectedLeague;
          final rosters = leagueProvider.selectedLeagueRosters;

          if (league == null) {
            return const Center(child: Text('League not found'));
          }

          return ResponsiveContainer(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // League info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            league.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Season ${league.season}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Transfer Commissioner section
                  Text(
                    'Transfer Commissioner',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transfer your commissioner role to another league member',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Members list for transfer
                  if (rosters.isEmpty)
                    Card(
                      child: Padding(
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
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
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text('Transfer'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 32),

                  // Danger Zone
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.red.withOpacity(0.05),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Danger Zone',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'These actions are irreversible. Proceed with caution.',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showRemoveConfirmation(
                                context,
                                leagueProvider,
                                authProvider,
                              );
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove All Members'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                  leagueId: widget.leagueId,
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
                    Navigator.of(context).pop();
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

  void _showRemoveConfirmation(
    BuildContext context,
    LeagueProvider leagueProvider,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All Members'),
        content: const Text(
          'This will remove all members from the league. This action cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This feature is coming soon'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
  }
}
