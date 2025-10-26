import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/roster_service.dart';

class RosterDetailsScreen extends StatefulWidget {
  final int rosterId;
  final String rosterName;

  const RosterDetailsScreen({
    super.key,
    required this.rosterId,
    required this.rosterName,
  });

  @override
  State<RosterDetailsScreen> createState() => _RosterDetailsScreenState();
}

class _RosterDetailsScreenState extends State<RosterDetailsScreen> {
  final RosterService _rosterService = RosterService();
  Map<String, dynamic>? _rosterData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      setState(() {
        _errorMessage = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    final roster = await _rosterService.getRosterWithPlayers(token, widget.rosterId);

    setState(() {
      _rosterData = roster;
      _isLoading = false;
      if (roster == null) {
        _errorMessage = 'Failed to load roster';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rosterName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRoster,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildRosterContent(),
    );
  }

  Widget _buildRosterContent() {
    if (_rosterData == null) return const SizedBox();

    final starters = _rosterData!['starters'] as List<dynamic>? ?? [];
    final bench = _rosterData!['bench'] as List<dynamic>? ?? [];
    final taxi = _rosterData!['taxi'] as List<dynamic>? ?? [];
    final ir = _rosterData!['ir'] as List<dynamic>? ?? [];

    final totalPlayers = starters.length + bench.length + taxi.length + ir.length;

    return RefreshIndicator(
      onRefresh: _loadRoster,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Roster Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          child: Text(
                            'R${_rosterData!['roster_id']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _rosterData!['username'] ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _rosterData!['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatChip('Total', totalPlayers.toString(), Colors.blue),
                        _buildStatChip('Starters', starters.length.toString(), Colors.green),
                        _buildStatChip('Bench', bench.length.toString(), Colors.orange),
                        if (taxi.isNotEmpty || ir.isNotEmpty)
                          _buildStatChip('Other', (taxi.length + ir.length).toString(), Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Starters Section
            if (starters.isNotEmpty) ...[
              _buildSectionHeader('Starters', starters.length, Colors.green),
              const SizedBox(height: 8),
              ...starters.map((player) => _buildPlayerCard(player, 'starter')),
              const SizedBox(height: 24),
            ] else ...[
              _buildSectionHeader('Starters', 0, Colors.green),
              const SizedBox(height: 8),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No starters set',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Bench Section
            if (bench.isNotEmpty) ...[
              _buildSectionHeader('Bench', bench.length, Colors.orange),
              const SizedBox(height: 8),
              ...bench.map((player) => _buildPlayerCard(player, 'bench')),
              const SizedBox(height: 24),
            ],

            // Taxi Section
            if (taxi.isNotEmpty) ...[
              _buildSectionHeader('Taxi Squad', taxi.length, Colors.purple),
              const SizedBox(height: 8),
              ...taxi.map((player) => _buildPlayerCard(player, 'taxi')),
              const SizedBox(height: 24),
            ],

            // IR Section
            if (ir.isNotEmpty) ...[
              _buildSectionHeader('Injured Reserve', ir.length, Colors.red),
              const SizedBox(height: 8),
              ...ir.map((player) => _buildPlayerCard(player, 'ir')),
            ],

            // Empty roster message
            if (totalPlayers == 0) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.group_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No players on roster',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Players will be added after the draft',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(dynamic player, String section) {
    if (player == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.help_outline),
          ),
          title: const Text('Unknown Player'),
          subtitle: const Text('Player data not available'),
        ),
      );
    }

    final fullName = player['full_name'] ?? 'Unknown Player';
    final position = player['position'] ?? '?';
    final team = player['team'] ?? 'FA';
    final age = player['age'];
    final yearsExp = player['years_exp'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPositionColor(position),
          child: Text(
            position,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$team${age != null ? ' • Age $age' : ''}${yearsExp != null ? ' • $yearsExp yr exp' : ''}',
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: () {
          // TODO: Navigate to player details screen
        },
      ),
    );
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case 'QB':
        return Colors.red.shade400;
      case 'RB':
        return Colors.green.shade400;
      case 'WR':
        return Colors.blue.shade400;
      case 'TE':
        return Colors.orange.shade400;
      case 'K':
        return Colors.purple.shade400;
      case 'DEF':
        return Colors.brown.shade400;
      case 'DL':
        return Colors.indigo.shade400;
      case 'LB':
        return Colors.cyan.shade400;
      case 'DB':
        return Colors.pink.shade400;
      default:
        return Colors.grey.shade400;
    }
  }
}
