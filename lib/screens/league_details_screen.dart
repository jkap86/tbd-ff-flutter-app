import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/roster_model.dart';
import '../widgets/responsive_container.dart';
import 'invite_members_screen.dart';
import 'edit_league_screen.dart';
import 'commissioner_settings_screen.dart';

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);

    await leagueProvider.loadLeagueDetails(widget.leagueId);

    if (authProvider.token != null) {
      await leagueProvider.checkIsCommissioner(
        token: authProvider.token!,
        leagueId: widget.leagueId,
      );
      await leagueProvider.loadLeagueStats(
        token: authProvider.token!,
        leagueId: widget.leagueId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('League Details'),
        actions: [
          Consumer2<LeagueProvider, AuthProvider>(
            builder: (context, leagueProvider, authProvider, child) {
              if (leagueProvider.isCommissioner) {
                return IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer2<LeagueProvider, AuthProvider>(
        builder: (context, leagueProvider, authProvider, child) {
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
          final currentUserId = authProvider.user?.id;
          final isCommissioner = leagueProvider.isCommissioner;

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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        league.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isCommissioner)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Commissioner',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isCommissioner)
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit League'),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  EditLeagueScreen(
                                                league: league,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      PopupMenuItem(
                                        child: const Row(
                                          children: [
                                            Icon(Icons.settings, size: 20),
                                            SizedBox(width: 8),
                                            Text('Commissioner Settings'),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CommissionerSettingsScreen(
                                                leagueId: league.id,
                                                leagueName: league.name,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                                Icons.calendar_today, 'Season', league.season),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.category,
                              'League Type',
                              _formatLeagueType(league.seasonType),
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
                          final isCurrentUser = roster.userId == currentUserId;
                          final isRosterCommissioner =
                              roster.userId == league.commissionerId;

                          return _buildRosterCard(
                            roster,
                            isCurrentUser: isCurrentUser,
                            isRosterCommissioner: isRosterCommissioner,
                            canRemove: isCommissioner && !isCurrentUser,
                            onRemove: () {
                              _showRemoveConfirmation(
                                context,
                                roster,
                                leagueProvider,
                                authProvider,
                              );
                            },
                          );
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

  Widget _buildRosterCard(
    Roster roster, {
    required bool isCurrentUser,
    required bool isRosterCommissioner,
    required bool canRemove,
    required VoidCallback onRemove,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            'R${roster.rosterId}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                roster.username ?? 'Unknown User',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isRosterCommissioner)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'C',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            if (isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(roster.email ?? ''),
        trailing: canRemove
            ? IconButton(
                icon:
                    const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: onRemove,
                tooltip: 'Remove Member',
              )
            : Column(
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

  void _showRemoveConfirmation(
    BuildContext context,
    Roster roster,
    LeagueProvider leagueProvider,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${roster.username} from the league?',
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
                final success = await leagueProvider.removeLeagueMember(
                  token: authProvider.token!,
                  leagueId: widget.leagueId,
                  userIdToRemove: roster.userId,
                );

                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${roster.username} removed from league'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          leagueProvider.errorMessage ??
                              'Failed to remove member',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
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

  String _formatLeagueType(String type) {
    switch (type) {
      case 'redraft':
        return 'Redraft';
      case 'dynasty':
        return 'Dynasty';
      case 'keeper':
        return 'Keeper';
      case 'betting':
        return 'Betting';
      default:
        return type;
    }
  }
}
