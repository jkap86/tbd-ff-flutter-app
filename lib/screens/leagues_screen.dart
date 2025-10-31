import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import '../widgets/common/error_state_widget.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/loading_skeletons.dart';
import 'create_league_screen.dart';
import 'league_details_screen.dart';
import 'join_league_screen.dart';

class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load leagues after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLeagues();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload leagues when app comes back to foreground
      _loadLeagues();
    }
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
          Semantics(
            label: 'Join League',
            button: true,
            child: IconButton(
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
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeagues,
        child: _buildBody(leagueProvider),
      ),
      floatingActionButton: Semantics(
        label: 'Create League',
        button: true,
        child: FloatingActionButton.extended(
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
      ),
    );
  }

  Widget _buildBody(LeagueProvider leagueProvider) {
    if (leagueProvider.status == LeagueStatus.loading) {
      return const ListSkeleton(itemCount: 4);
    }

    if (leagueProvider.status == LeagueStatus.error) {
      return ErrorStateWidget(
        message: leagueProvider.errorMessage ?? 'Error loading leagues',
        onRetry: _loadLeagues,
      );
    }

    if (leagueProvider.userLeagues.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.sports_football,
        iconSize: 80,
        title: 'No leagues yet',
        subtitle: 'Create your first league or join an existing one to get started!',
        actionLabel: 'Create League',
        onAction: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateLeagueScreen(),
            ),
          );
          if (result == true) {
            _loadLeagues();
          }
        },
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
              child: Semantics(
                label: '${league.name}, ${_formatLeagueType(league.leagueType)}, ${_formatStatus(league.status)}, ${league.currentRosters ?? league.totalRosters} of ${league.totalRosters} teams${isCommissioner ? ', Commissioner' : ''}',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            LeagueDetailsScreen(leagueId: league.id),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with title and commissioner badge
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.sports_football,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  league.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isCommissioner)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.warning,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'Commissioner',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // League info
                          Row(
                            children: [
                              Text(
                                'Season: ${league.season}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Text(
                                'Teams: ${league.currentRosters ?? league.totalRosters}/${league.totalRosters}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Status badges
                          Row(
                            children: [
                              _buildLeagueTypeChip(league.leagueType),
                              const SizedBox(width: 8),
                              _buildStatusChip(league.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
      default:
        return type;
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pre_draft':
        color = AppColors.warning;
        label = 'Pre-Draft';
        break;
      case 'drafting':
        color = AppColors.primary;
        label = 'Drafting';
        break;
      case 'in_season':
        color = AppColors.secondary;
        label = 'In Season';
        break;
      case 'complete':
        color = AppColors.textSecondary;
        label = 'Complete';
        break;
      default:
        color = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLeagueTypeChip(String type) {
    Color color;
    String label;

    switch (type) {
      case 'redraft':
        color = AppColors.primary;
        label = 'Redraft';
        break;
      case 'dynasty':
        color = AppColors.accent;
        label = 'Dynasty';
        break;
      case 'keeper':
        color = AppColors.warning;
        label = 'Keeper';
        break;
      default:
        color = AppColors.textSecondary;
        label = type;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
