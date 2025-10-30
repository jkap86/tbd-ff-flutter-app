import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_model.dart';
import '../services/injury_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/injury_badge_widget.dart';

class InjuryReportScreen extends StatefulWidget {
  final int leagueId;

  const InjuryReportScreen({
    super.key,
    required this.leagueId,
  });

  @override
  State<InjuryReportScreen> createState() => _InjuryReportScreenState();
}

class _InjuryReportScreenState extends State<InjuryReportScreen> {
  List<dynamic> _injuries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInjuries();
  }

  Future<void> _loadInjuries() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token!;

      final injuries = await InjuryService.getLeagueInjuryReport(
        token,
        widget.leagueId,
      );

      setState(() {
        _injuries = injuries;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load injuries: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Injury Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInjuries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _injuries.isEmpty
              ? const Center(child: Text('No injuries to report'))
              : RefreshIndicator(
                  onRefresh: _loadInjuries,
                  child: ListView.builder(
                    itemCount: _injuries.length,
                    itemBuilder: (context, index) {
                      final injury = _injuries[index];
                      return _buildInjuryCard(injury);
                    },
                  ),
                ),
    );
  }

  Widget _buildInjuryCard(Map<String, dynamic> injury) {
    final player = Player.fromJson(injury);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              player.position,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            InjuryBadgeWidget(player: player, size: 24),
          ],
        ),
        title: Text(
          player.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${player.team} - ${injury['team_name'] ?? 'Unknown Team'}'),
            if (player.injuryDesignation != null)
              Text(
                player.injuryDesignation!,
                style: TextStyle(
                  color: player.injuryStatusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: player.injuryReturnDate != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Est. Return:', style: TextStyle(fontSize: 10)),
                  Text(
                    '${player.injuryReturnDate!.month}/${player.injuryReturnDate!.day}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
