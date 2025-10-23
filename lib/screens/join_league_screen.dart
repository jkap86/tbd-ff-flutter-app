import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/invite_provider.dart';
import '../providers/league_provider.dart';
import '../models/league_invite_model.dart';
import '../widgets/responsive_container.dart';
import 'league_details_screen.dart';

class JoinLeagueScreen extends StatefulWidget {
  const JoinLeagueScreen({super.key});

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _publicLeagues = [];
  bool _isLoadingPublic = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPublicLeagues();
    _loadUserInvites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPublicLeagues() async {
    setState(() {
      _isLoadingPublic = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/leagues/public'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _publicLeagues = data['data'] as List;
          _isLoadingPublic = false;
        });
      } else if (mounted) {
        setState(() {
          _publicLeagues = [];
          _isLoadingPublic = false;
        });
      }
    } catch (e) {
      print('Error loading public leagues: $e');
      if (mounted) {
        setState(() {
          _publicLeagues = [];
          _isLoadingPublic = false;
        });
      }
    }
  }

  Future<void> _loadUserInvites() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final inviteProvider = Provider.of<InviteProvider>(context, listen: false);

    if (authProvider.user != null) {
      await inviteProvider.loadUserInvites(authProvider.user!.id);
    }
  }

  Future<void> _joinPublicLeague(int leagueId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
      }
      return;
    }

    final success = await leagueProvider.joinLeague(
      token: authProvider.token!,
      leagueId: leagueId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined league!')),
      );
      Navigator.of(context).pop(true); // Return to leagues screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(leagueProvider.errorMessage ?? 'Failed to join league'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptInvite(LeagueInvite invite) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final inviteProvider = Provider.of<InviteProvider>(context, listen: false);

    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    final success = await inviteProvider.acceptInvite(
      token: authProvider.token!,
      inviteId: invite.id,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invite accepted! Welcome to the league!')),
        );
        // Optionally navigate to league details
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                LeagueDetailsScreen(leagueId: invite.leagueId),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(inviteProvider.errorMessage ?? 'Failed to accept invite'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineInvite(LeagueInvite invite) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final inviteProvider = Provider.of<InviteProvider>(context, listen: false);

    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    final success = await inviteProvider.declineInvite(
      token: authProvider.token!,
      inviteId: invite.id,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite declined')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(inviteProvider.errorMessage ?? 'Failed to decline invite'),
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
        title: const Text('Join League'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Browse Public', icon: Icon(Icons.public)),
            Tab(text: 'My Invites', icon: Icon(Icons.mail)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPublicLeaguesTab(),
          _buildInvitesTab(),
        ],
      ),
    );
  }

  Widget _buildPublicLeaguesTab() {
    if (_isLoadingPublic) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_publicLeagues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.public_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No public leagues available',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later or create your own!',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublicLeagues,
      child: ResponsiveContainer(
        maxWidth: 800,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _publicLeagues.length,
          itemBuilder: (context, index) {
            final league = _publicLeagues[index];
            final currentRosters =
                int.tryParse(league['current_rosters']?.toString() ?? '0') ?? 0;
            final totalRosters =
                int.tryParse(league['total_rosters']?.toString() ?? '12') ?? 12;
            final isFull = currentRosters >= totalRosters;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sports_football,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            league['name'] ?? 'Unknown League',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoChip(
                            Icons.calendar_today, league['season'] ?? 'N/A'),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.category,
                          _formatLeagueType(league['season_type'] ?? 'redraft'),
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.people,
                          '$currentRosters/$totalRosters teams',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isFull
                            ? null
                            : () => _joinPublicLeague(league['id']),
                        child: Text(isFull ? 'League Full' : 'Join League'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInvitesTab() {
    return Consumer<InviteProvider>(
      builder: (context, inviteProvider, child) {
        if (inviteProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (inviteProvider.userInvites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pending invites',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invites from other users will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadUserInvites,
          child: ResponsiveContainer(
            maxWidth: 800,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inviteProvider.userInvites.length,
              itemBuilder: (context, index) {
                final invite = inviteProvider.userInvites[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                invite.inviterUsername?[0].toUpperCase() ?? 'U',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invite.leagueName ?? 'Unknown League',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Invited by ${invite.inviterUsername ?? "Unknown"}',
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
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (invite.season != null)
                              _buildInfoChip(
                                  Icons.calendar_today, invite.season!),
                            const SizedBox(width: 8),
                            if (invite.totalRosters != null)
                              _buildInfoChip(
                                Icons.people,
                                '${invite.totalRosters} teams',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _declineInvite(invite),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _acceptInvite(invite),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
