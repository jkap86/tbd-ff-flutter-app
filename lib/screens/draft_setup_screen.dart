import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/draft_provider.dart';
import '../widgets/responsive_container.dart';
import 'draft_room_screen.dart';

class DraftSetupScreen extends StatefulWidget {
  final int leagueId;
  final String leagueName;

  const DraftSetupScreen({
    super.key,
    required this.leagueId,
    required this.leagueName,
  });

  @override
  State<DraftSetupScreen> createState() => _DraftSetupScreenState();
}

class _DraftSetupScreenState extends State<DraftSetupScreen> {
  String _draftType = 'snake';
  bool _thirdRoundReversal = false;
  int _pickTimeSeconds = 90;
  int _rounds = 15;
  String _timerMode = 'standard'; // 'standard' or 'slow'

  bool _isCreating = false;

  Future<void> _handleCreateDraft() async {
    setState(() => _isCreating = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);

    if (authProvider.token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
      }
      setState(() => _isCreating = false);
      return;
    }

    final success = await draftProvider.createDraft(
      token: authProvider.token!,
      leagueId: widget.leagueId,
      draftType: _draftType,
      thirdRoundReversal: _thirdRoundReversal,
      pickTimeSeconds: _pickTimeSeconds,
      rounds: _rounds,
    );

    if (mounted) {
      setState(() => _isCreating = false);

      if (success) {
        // Navigate directly to draft room
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DraftRoomScreen(
              leagueId: widget.leagueId,
              leagueName: widget.leagueName,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                draftProvider.errorMessage ?? 'Failed to create draft'),
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
        title: Text('Setup Draft - ${widget.leagueName}'),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Draft icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.format_list_numbered,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Draft Type Selection
                Text(
                  'Draft Type',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'snake',
                      label: Text('Snake'),
                      icon: Icon(Icons.swap_vert),
                    ),
                    ButtonSegment(
                      value: 'linear',
                      label: Text('Linear'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {_draftType},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _draftType = selection.first;
                      // Reset 3RR if switching to linear
                      if (_draftType == 'linear') {
                        _thirdRoundReversal = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _draftType == 'snake'
                      ? 'Draft order reverses every round (1-12, 12-1, 1-12...)'
                      : 'Same draft order every round (1-12, 1-12, 1-12...)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),

                // Third Round Reversal (only for snake)
                if (_draftType == 'snake') ...[
                  Card(
                    child: SwitchListTile(
                      title: const Text('3rd Round Reversal'),
                      subtitle: const Text(
                          'Reverse order in round 3 (1-12 instead of 12-1)'),
                      value: _thirdRoundReversal,
                      onChanged: (value) {
                        setState(() => _thirdRoundReversal = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Pick Time
                Text(
                  'Pick Timer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'standard',
                      label: Text('Standard'),
                      icon: Icon(Icons.timer),
                    ),
                    ButtonSegment(
                      value: 'slow',
                      label: Text('Slow Draft'),
                      icon: Icon(Icons.schedule),
                    ),
                  ],
                  selected: {_timerMode},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _timerMode = selection.first;
                      // Set default for mode
                      if (_timerMode == 'standard') {
                        _pickTimeSeconds = 90;
                      } else {
                        _pickTimeSeconds = 3600; // 1 hour default for slow
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getTimerLabel(),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              _getTimerDisplay(),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _pickTimeSeconds.toDouble(),
                          min: _timerMode == 'standard' ? 30 : 300,
                          max: _timerMode == 'standard' ? 300 : 86400,
                          divisions: _timerMode == 'standard' ? 27 : _getSlowDivisions(),
                          label: _getTimerDisplay(),
                          onChanged: (value) {
                            setState(() =>
                                _pickTimeSeconds = _snapToInterval(value.toInt()));
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_timerMode == 'standard' ? '30s' : '5m',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(_timerMode == 'standard' ? '5m' : '24h',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Number of Rounds
                Text(
                  'Number of Rounds',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$_rounds rounds',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              '$_rounds',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _rounds.toDouble(),
                          min: 10,
                          max: 20,
                          divisions: 10,
                          label: '$_rounds',
                          onChanged: (value) {
                            setState(() => _rounds = value.toInt());
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('10',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text('20',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Draft Summary
                Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Draft Summary',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Type', _draftType.toUpperCase()),
                        if (_draftType == 'snake' && _thirdRoundReversal)
                          _buildSummaryRow('3RR', 'Enabled'),
                        _buildSummaryRow(
                            'Pick Timer', _getTimerSummary()),
                        _buildSummaryRow('Rounds', '$_rounds'),
                        _buildSummaryRow('Total Picks',
                            '${_rounds * 12}'), // Assuming 12 teams
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Create Draft Button
                FilledButton(
                  onPressed: _isCreating ? null : _handleCreateDraft,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Draft'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimerLabel() {
    if (_timerMode == 'standard') {
      return '$_pickTimeSeconds seconds per pick';
    } else {
      return 'Time per pick';
    }
  }

  String _getTimerDisplay() {
    if (_timerMode == 'standard') {
      final minutes = _pickTimeSeconds ~/ 60;
      final seconds = _pickTimeSeconds % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      // Slow draft display
      if (_pickTimeSeconds < 3600) {
        // Less than 1 hour - show minutes
        final minutes = _pickTimeSeconds ~/ 60;
        return '${minutes}m';
      } else if (_pickTimeSeconds < 86400) {
        // Less than 1 day - show hours
        final hours = _pickTimeSeconds ~/ 3600;
        return '${hours}h';
      } else {
        // Show days
        final days = _pickTimeSeconds ~/ 86400;
        return '${days}d';
      }
    }
  }

  String _getTimerSummary() {
    if (_pickTimeSeconds < 60) {
      return '${_pickTimeSeconds}s';
    } else if (_pickTimeSeconds < 3600) {
      final minutes = _pickTimeSeconds ~/ 60;
      return '${minutes}m';
    } else if (_pickTimeSeconds < 86400) {
      final hours = _pickTimeSeconds ~/ 3600;
      return '${hours}h';
    } else {
      final days = _pickTimeSeconds ~/ 86400;
      return '${days}d';
    }
  }

  int _getSlowDivisions() {
    // Slow draft intervals:
    // 5m, 10m, 15m, 20m, 30m, 1h, 2h, 4h, 8h, 12h, 18h, 24h
    return 11;
  }

  int _snapToInterval(int seconds) {
    if (_timerMode == 'standard') {
      // Standard mode: snap to 10 second intervals
      return (seconds ~/ 10) * 10;
    } else {
      // Slow draft mode: snap to specific intervals
      const intervals = [
        300,    // 5 minutes
        600,    // 10 minutes
        900,    // 15 minutes
        1200,   // 20 minutes
        1800,   // 30 minutes
        3600,   // 1 hour
        7200,   // 2 hours
        14400,  // 4 hours
        28800,  // 8 hours
        43200,  // 12 hours
        64800,  // 18 hours
        86400,  // 24 hours
      ];

      // Find closest interval
      int closest = intervals[0];
      int minDiff = (seconds - intervals[0]).abs();

      for (int interval in intervals) {
        int diff = (seconds - interval).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = interval;
        }
      }

      return closest;
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
