import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/invite_provider.dart';
import '../models/user_search_model.dart';
import '../widgets/responsive_container.dart';

class InviteMembersScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;

  const InviteMembersScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  final _searchController = TextEditingController();
  final Set<int> _sentInvites = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.trim().length >= 2) {
      final inviteProvider =
          Provider.of<InviteProvider>(context, listen: false);
      inviteProvider.searchUsers(query);
    } else {
      final inviteProvider =
          Provider.of<InviteProvider>(context, listen: false);
      inviteProvider.clearSearchResults();
    }
  }

  Future<void> _sendInvite(UserSearchResult user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final inviteProvider = Provider.of<InviteProvider>(context, listen: false);

    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    final success = await inviteProvider.sendInvite(
      token: authProvider.token!,
      leagueId: widget.leagueId,
      invitedUserId: user.id,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _sentInvites.add(user.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to ${user.username}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(inviteProvider.errorMessage ?? 'Failed to send invite'),
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
        title: const Text('Invite Members'),
      ),
      body: ResponsiveContainer(
        child: Column(
          children: [
            // League info banner
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.sports_football,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inviting to:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.8),
                          ),
                        ),
                        Text(
                          widget.leagueName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search users',
                  hintText: 'Enter username or email',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Search results
            Expanded(
              child: Consumer<InviteProvider>(
                builder: (context, inviteProvider, child) {
                  if (inviteProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_searchController.text.trim().length < 2) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Search for users to invite',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter at least 2 characters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (inviteProvider.searchResults.isEmpty) {
                    return const Center(
                      child: Text('No users found'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: inviteProvider.searchResults.length,
                    itemBuilder: (context, index) {
                      final user = inviteProvider.searchResults[index];
                      final alreadySent = _sentInvites.contains(user.id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              user.username[0].toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            user.username,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(user.email),
                          trailing: alreadySent
                              ? const Chip(
                                  label: Text('Invited'),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(color: Colors.white),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () => _sendInvite(user),
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Invite'),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
