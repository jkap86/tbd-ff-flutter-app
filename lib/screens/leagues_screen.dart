import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../widgets/responsive_container.dart';
import 'create_league_screen.dart';
import 'league_details_screen.dart';
import 'join_league_screen.dart';

class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);

    if (authProvider.user != null) {
      await leagueProvider.loadUserLeagues(authProvider.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leagueProvider = Provider.of<LeagueProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leagues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const JoinLeagueScreen(),
                ),
              );

              if (result == true) {
                _loadLeagues();
              }
            },
            tooltip: 'Join League',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeagues,
        child: _buildBody(leagueProvider),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateLeagueScreen(),
            ),
          );

          if (result == true) {
            _loadLeagues();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create League'),
      ),
    );
  }

  Widget _buildBody(LeagueProvider leagueProvider) {
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
              leagueProvider.errorMessage ?? 'Error loading leagues',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLeagues,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (leagueProvider.userLeagues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_football,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No leagues yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first league to get started!',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentUserId = authProvider.user?.id;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leagueProvider.userLeagues.length,
          itemBuilder: (context, index) {
            final league = leagueProvider.userLeagues[index];
            final isCommissioner = league.commissionerId == currentUserId;

            return ResponsiveContainer(
              maxWidth: 800,
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.sports_football,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          league.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isCommissioner)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'C',
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Season: ${league.season}'),
                      Text(
                        'Teams: ${league.currentRosters ?? league.totalRosters}/${league.totalRosters}',
                      ),
                      const SizedBox(height: 4),
                      _buildLeagueTypeChip(league.seasonType),
                      const SizedBox(height: 4),
                      _buildStatusChip(league.status),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            LeagueDetailsScreen(leagueId: league.id),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pre_draft':
        color = Colors.orange;
        label = 'Pre-Draft';
        break;
      case 'drafting':
        color = Colors.blue;
        label = 'Drafting';
        break;
      case 'in_season':
        color = Colors.green;
        label = 'In Season';
        break;
      case 'complete':
        color = Colors.grey;
        label = 'Complete';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLeagueTypeChip(String type) {
    Color color;
    String label;

    switch (type) {
      case 'redraft':
        color = Colors.blue;
        label = 'Redraft';
        break;
      case 'dynasty':
        color = Colors.purple;
        label = 'Dynasty';
        break;
      case 'keeper':
        color = Colors.orange;
        label = 'Keeper';
        break;
      case 'betting':
        color = Colors.red;
        label = 'Betting';
        break;
      default:
        color = Colors.grey;
        label = type;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
