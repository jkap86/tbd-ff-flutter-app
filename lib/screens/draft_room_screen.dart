import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/draft_provider.dart';
import '../models/player_model.dart';
import '../widgets/draft_board_widget.dart';
import '../widgets/draft_chat_widget.dart';

class DraftRoomScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;

  const DraftRoomScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<DraftRoomScreen> createState() => _DraftRoomScreenState();
}

class _DraftRoomScreenState extends State<DraftRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPosition;
  Player? _selectedPlayer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDraftAndJoinRoom();
  }

  Future<void> _loadDraftAndJoinRoom() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    await draftProvider.loadDraftByLeague(widget.leagueId);

    if (draftProvider.currentDraft != null && authProvider.user != null) {
      // Join WebSocket room
      draftProvider.joinDraftRoom(
        draftId: draftProvider.currentDraft!.id,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();

    // Leave WebSocket room
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (draftProvider.currentDraft != null && authProvider.user != null) {
      draftProvider.leaveDraftRoom(
        draftId: draftProvider.currentDraft!.id,
        userId: authProvider.user!.id,
        username: authProvider.user!.username,
      );
    }

    super.dispose();
  }

  Future<void> _makePick() async {
    if (_selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a player first')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null ||
        draftProvider.currentDraft == null) {
      return;
    }

    // TODO: Get actual roster ID for current user
    final rosterId = draftProvider.currentDraft!.currentRosterId;
    if (rosterId == null) return;

    final success = await draftProvider.makePick(
      token: authProvider.token!,
      draftId: draftProvider.currentDraft!.id,
      rosterId: rosterId,
      playerId: _selectedPlayer!.id,
    );

    if (mounted) {
      if (success) {
        setState(() => _selectedPlayer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Picked ${_selectedPlayer!.fullName}!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                draftProvider.errorMessage ?? 'Failed to make pick'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _filterPlayers() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    await draftProvider.filterPlayers(
      position: _selectedPosition,
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Draft - ${widget.leagueName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Players'),
            Tab(icon: Icon(Icons.grid_on), text: 'Board'),
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
          ],
        ),
      ),
      body: Consumer<DraftProvider>(
        builder: (context, draftProvider, child) {
          final draft = draftProvider.currentDraft;

          if (draft == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Draft Status Bar
              _buildStatusBar(draftProvider),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Players Tab
                    _buildPlayersTab(draftProvider),

                    // Draft Board Tab
                    const DraftBoardWidget(),

                    // Chat Tab
                    const DraftChatWidget(),
                  ],
                ),
              ),

              // Pick Button (if it's user's turn)
              if (draft.isInProgress && _selectedPlayer != null)
                _buildPickButton(draftProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(DraftProvider draftProvider) {
    final draft = draftProvider.currentDraft!;
    final timeRemaining = draftProvider.timeRemaining;

    // Find the roster on the clock from draft order
    final currentRoster = draftProvider.draftOrder.firstWhere(
      (order) => order.rosterId == draft.currentRosterId,
      orElse: () => draftProvider.draftOrder.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Round ${draft.currentRound}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Pick ${draft.currentPick}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (timeRemaining != null)
                Column(
                  children: [
                    Text(
                      '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: timeRemaining.inSeconds < 10
                                ? Colors.red
                                : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    Text(
                      'Time Remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'On the Clock',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    currentRoster.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: draft.progressPercentage,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersTab(DraftProvider draftProvider) {
    return Column(
      children: [
        // Search and Filter
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search players...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPlayers();
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => _filterPlayers(),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedPosition == null,
                      onSelected: (selected) {
                        setState(() => _selectedPosition = null);
                        _filterPlayers();
                      },
                    ),
                    const SizedBox(width: 8),
                    ...['QB', 'RB', 'WR', 'TE', 'K', 'DEF'].map((pos) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(pos),
                          selected: _selectedPosition == pos,
                          onSelected: (selected) {
                            setState(() =>
                                _selectedPosition = selected ? pos : null);
                            _filterPlayers();
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Players List
        Expanded(
          child: draftProvider.availablePlayers.isEmpty
              ? const Center(child: Text('No players available'))
              : ListView.builder(
                  itemCount: draftProvider.availablePlayers.length,
                  itemBuilder: (context, index) {
                    final player = draftProvider.availablePlayers[index];
                    final isSelected = _selectedPlayer?.id == player.id;

                    return ListTile(
                      selected: isSelected,
                      leading: CircleAvatar(
                        child: Text(player.position),
                      ),
                      title: Text(player.fullName),
                      subtitle: Text(player.positionTeam),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedPlayer = isSelected ? null : player;
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPickButton(DraftProvider draftProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedPlayer != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Text(_selectedPlayer!.position),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPlayer!.fullName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _selectedPlayer!.positionTeam,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _makePick,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text('Draft ${_selectedPlayer!.fullName}'),
          ),
        ],
      ),
    );
  }
}
