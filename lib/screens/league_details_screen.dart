import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/league_provider.dart';
import '../models/roster_model.dart';
import '../widgets/responsive_container.dart';
import 'invite_members_screen.dart';

class LeagueDetailsScreen extends StatefulWidget {
  final int leagueId;

  const LeagueDetailsScreen({
    super.key,
    required this.leagueId,
  });

  @override
  State<LeagueDetailsScreen> createState() => _LeagueDetailsScreenState();
}

class _LeagueDetailsScreenState extends State<LeagueDetailsScreen> {
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
        title: const Text('League Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              final leagueProvider =
                  Provider.of<LeagueProvider>(context, listen: false);
              final league = leagueProvider.selectedLeague;
              if (league != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InviteMembersScreen(
                      leagueId: league.id,
                      leagueName: league.name,
                    ),
                  ),
                );
              }
            },
            tooltip: 'Invite Members',
          ),
        ],
      ),
      body: Consumer<LeagueProvider>(
        builder: (context, leagueProvider, child) {
          if (leagueProvider.status == LeagueStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (leagueProvider.status == LeagueStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    leagueProvider.errorMessage ?? 'Error loading league',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadLeagueDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final league = leagueProvider.selectedLeague;
          final rosters = leagueProvider.selectedLeagueRosters;

          if (league == null) {
            return const Center(child: Text('League not found'));
          }

          return RefreshIndicator(
            onRefresh: _loadLeagueDetails,
            child: ResponsiveContainer(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // League info card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.sports_football,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    league.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                                Icons.calendar_today, 'Season', league.season),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.category,
                              'Type',
                              league.seasonType.toUpperCase(),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.people,
                              'Teams',
                              '${rosters.length}/${league.totalRosters}',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.circle,
                              'Status',
                              _formatStatus(league.status),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Rosters section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Teams',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${rosters.length} teams',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rosters list
                    if (rosters.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No teams in this league yet'),
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
                          return _buildRosterCard(roster);
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRosterCard(Roster roster) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            'R${roster.rosterId}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          roster.username ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(roster.email ?? ''),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Roster ${roster.rosterId}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${roster.starters.length + roster.bench.length} players',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pre_draft':
        return 'Pre-Draft';
      case 'drafting':
        return 'Drafting';
      case 'in_season':
        return 'In Season';
      case 'complete':
        return 'Complete';
      default:
        return status;
    }
  }
}
