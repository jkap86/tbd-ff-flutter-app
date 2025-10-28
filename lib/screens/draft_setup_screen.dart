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

  // Overnight pause settings
  bool _autoPauseEnabled = false;
  TimeOfDay _autoPauseStartTime = const TimeOfDay(hour: 23, minute: 0); // 11:00 PM
  TimeOfDay _autoPauseEndTime = const TimeOfDay(hour: 8, minute: 0); // 8:00 AM

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

    // Convert local time to UTC before saving
    Map<String, dynamic>? draftSettings;
    if (_autoPauseEnabled) {
      final startUTC = _localTimeOfDayToUTC(_autoPauseStartTime);
      final endUTC = _localTimeOfDayToUTC(_autoPauseEndTime);
      draftSettings = {
        'auto_pause_enabled': true,
        'auto_pause_start_hour': startUTC['hour'],
        'auto_pause_start_minute': startUTC['minute'],
        'auto_pause_end_hour': endUTC['hour'],
        'auto_pause_end_minute': endUTC['minute'],
      };
    }

    final success = await draftProvider.createDraft(
      token: authProvider.token!,
      leagueId: widget.leagueId,
      draftType: _draftType,
      thirdRoundReversal: _thirdRoundReversal,
      pickTimeSeconds: _pickTimeSeconds,
      rounds: _rounds,
      settings: draftSettings,
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
                          min: 10,
                          max: 300,
                          divisions: 29,
                          label: _getTimerDisplay(),
                          onChanged: (value) {
                            setState(() => _pickTimeSeconds = value.toInt());
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('10s',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text('5m',
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
                const SizedBox(height: 24),

                // Overnight Pause
                Text(
                  'Overnight Pause',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Auto-Pause Overnight'),
                        subtitle: const Text(
                            'Automatically pause draft during specified hours'),
                        value: _autoPauseEnabled,
                        onChanged: (value) {
                          setState(() => _autoPauseEnabled = value);
                        },
                      ),
                      if (_autoPauseEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.bedtime),
                          title: const Text('Pause at'),
                          trailing: TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _autoPauseStartTime,
                              );
                              if (time != null) {
                                setState(() => _autoPauseStartTime = time);
                              }
                            },
                            child: Text(
                              _autoPauseStartTime.format(context),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.wb_sunny),
                          title: const Text('Resume at'),
                          trailing: TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _autoPauseEndTime,
                              );
                              if (time != null) {
                                setState(() => _autoPauseEndTime = time);
                              }
                            },
                            child: Text(
                              _autoPauseEndTime.format(context),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                        if (_autoPauseEnabled)
                          _buildSummaryRow(
                              'Auto-Pause',
                              '${_autoPauseStartTime.format(context)} - ${_autoPauseEndTime.format(context)}')
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
    return '$_pickTimeSeconds seconds per pick';
  }

  String _getTimerDisplay() {
    final minutes = _pickTimeSeconds ~/ 60;
    final seconds = _pickTimeSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getTimerSummary() {
    if (_pickTimeSeconds < 60) {
      return '${_pickTimeSeconds}s';
    } else {
      final minutes = _pickTimeSeconds ~/ 60;
      final seconds = _pickTimeSeconds % 60;
      if (seconds == 0) {
        return '${minutes}m';
      } else {
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    }
  }

  /// Convert local TimeOfDay to UTC
  Map<String, int> _localTimeOfDayToUTC(TimeOfDay localTime) {
    // Create a local DateTime for today with the given time
    final now = DateTime.now();
    final localDateTime = DateTime(now.year, now.month, now.day, localTime.hour, localTime.minute);

    // Convert to UTC
    final utcTime = localDateTime.toUtc();

    return {
      'hour': utcTime.hour,
      'minute': utcTime.minute,
    };
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
