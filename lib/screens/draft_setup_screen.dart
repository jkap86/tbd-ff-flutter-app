import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/draft_provider.dart';
import '../widgets/responsive_container.dart';

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

  // Timer mode settings
  String _timerMode = 'traditional'; // 'traditional' or 'chess'
  int _teamTimeBudgetMinutes = 60; // Only used in chess mode

  // Overnight pause settings
  bool _autoPauseEnabled = false;
  TimeOfDay _autoPauseStartTime = const TimeOfDay(hour: 23, minute: 0); // 11:00 PM
  TimeOfDay _autoPauseEndTime = const TimeOfDay(hour: 8, minute: 0); // 8:00 AM

  // Auction-specific fields
  int _startingBudget = 200;
  int _minBid = 1;
  int _nominationsPerManager = 3;
  int _nominationTimerHours = 24;
  bool _reserveBudgetPerSlot = false;

  // Derby-specific fields
  bool _derbyEnabled = false;
  int _derbyTimeLimitSeconds = 120; // 2 minutes default
  String _derbyTimeoutBehavior = 'auto'; // 'auto' or 'skip'

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
    Map<String, dynamic> draftSettings = {};

    // Add overnight pause settings
    if (_autoPauseEnabled) {
      final startUTC = _localTimeOfDayToUTC(_autoPauseStartTime);
      final endUTC = _localTimeOfDayToUTC(_autoPauseEndTime);
      draftSettings.addAll({
        'auto_pause_enabled': true,
        'auto_pause_start_hour': startUTC['hour'],
        'auto_pause_start_minute': startUTC['minute'],
        'auto_pause_end_hour': endUTC['hour'],
        'auto_pause_end_minute': endUTC['minute'],
      });
    }

    final success = await draftProvider.createDraft(
      token: authProvider.token!,
      leagueId: widget.leagueId,
      draftType: _draftType,
      thirdRoundReversal: _thirdRoundReversal,
      pickTimeSeconds: _pickTimeSeconds,
      rounds: _rounds,
      timerMode: _timerMode,
      teamTimeBudgetSeconds: _timerMode == 'chess' ? _teamTimeBudgetMinutes * 60 : null,
      settings: draftSettings,
      // Auction-specific params
      startingBudget: (_draftType == 'auction' || _draftType == 'slow_auction') ? _startingBudget : null,
      minBid: (_draftType == 'auction' || _draftType == 'slow_auction') ? _minBid : null,
      nominationsPerManager: _draftType == 'slow_auction' ? _nominationsPerManager : null,
      nominationTimerHours: _draftType == 'slow_auction' ? _nominationTimerHours : null,
      reserveBudgetPerSlot: (_draftType == 'auction' || _draftType == 'slow_auction') ? _reserveBudgetPerSlot : null,
      // Derby-specific params
      derbyEnabled: (_draftType == 'snake' || _draftType == 'linear') ? _derbyEnabled : false,
      derbyTimeLimitSeconds: _derbyEnabled ? _derbyTimeLimitSeconds : null,
      derbyTimeoutBehavior: _derbyEnabled ? _derbyTimeoutBehavior : null,
    );

    if (mounted) {
      setState(() => _isCreating = false);

      if (success) {
        // Show success message and navigate back to League Details
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft created successfully! Randomize the draft order before starting.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(); // Go back to League Details
        }
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Snake'),
                      selected: _draftType == 'snake',
                      onSelected: (_) => setState(() => _draftType = 'snake'),
                    ),
                    ChoiceChip(
                      label: const Text('Linear'),
                      selected: _draftType == 'linear',
                      onSelected: (_) => setState(() {
                        _draftType = 'linear';
                        _thirdRoundReversal = false;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Auction'),
                      selected: _draftType == 'auction',
                      onSelected: (_) => setState(() => _draftType = 'auction'),
                    ),
                    ChoiceChip(
                      label: const Text('Slow Auction'),
                      selected: _draftType == 'slow_auction',
                      onSelected: (_) => setState(() => _draftType = 'slow_auction'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getDraftTypeDescription(),
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

                // Auction Settings (only for auction/slow_auction)
                if (_draftType == 'auction' || _draftType == 'slow_auction') ...[
                  ..._buildAuctionSettings(),
                  const SizedBox(height: 24),
                ],

                // Timer Mode Selection (only for snake/linear)
                if (_draftType == 'snake' || _draftType == 'linear') ...[
                  Text(
                    'Timer Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'traditional',
                        label: Text('Traditional'),
                        icon: Icon(Icons.timer),
                      ),
                      ButtonSegment(
                        value: 'chess',
                        label: Text('Chess Timer'),
                        icon: Icon(Icons.hourglass_bottom),
                      ),
                    ],
                    selected: {_timerMode},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _timerMode = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _timerMode == 'traditional'
                        ? 'Fixed time per pick. Timer resets after each selection.'
                        : 'Each team has a total time budget. Time bank runs down during their picks.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),

                  // Chess Timer Budget (only visible when chess mode selected)
                  if (_timerMode == 'chess') ...[
                    Text(
                      'Team Time Budget',
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
                                  'Time per team',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(
                                  _getTimeBudgetDisplay(),
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
                              value: _teamTimeBudgetMinutes.toDouble(),
                              min: 15,
                              max: 360,
                              divisions: 69, // 5-minute increments
                              label: _getTimeBudgetDisplay(),
                              onChanged: (value) {
                                setState(() {
                                  // Round to nearest 5 minutes
                                  _teamTimeBudgetMinutes = (value / 5).round() * 5;
                                });
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('15m',
                                    style: Theme.of(context).textTheme.bodySmall),
                                Text('6h',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Quick preset buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildPresetButton(30, '30 min'),
                                _buildPresetButton(60, '1 hour'),
                                _buildPresetButton(120, '2 hours'),
                                _buildPresetButton(180, '3 hours'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Pick Time (Traditional mode only)
                  if (_timerMode == 'traditional') ...[
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
                  ],
                ],

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

                // Draft Slot Selection Derby (only for snake/linear)
                if (_draftType == 'snake' || _draftType == 'linear') ...[
                  Text(
                    'Draft Slot Selection Derby',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable Derby'),
                          subtitle: const Text(
                              'Let managers choose their draft position before the draft starts'),
                          value: _derbyEnabled,
                          onChanged: (value) {
                            setState(() => _derbyEnabled = value);
                          },
                        ),
                        if (_derbyEnabled) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Derby Time Limit
                                Text(
                                  'Time Limit Per Selection',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _getDerbyTimerDisplay(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      '${_derbyTimeLimitSeconds}s',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _derbyTimeLimitSeconds.toDouble(),
                                  min: 30,
                                  max: 300,
                                  divisions: 27,
                                  label: _getDerbyTimerDisplay(),
                                  onChanged: (value) {
                                    setState(() => _derbyTimeLimitSeconds = value.toInt());
                                  },
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('30s', style: Theme.of(context).textTheme.bodySmall),
                                    Text('5m', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Timeout Behavior
                                Text(
                                  'If Time Expires',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'auto',
                                      label: Text('Auto-Assign'),
                                      icon: Icon(Icons.auto_fix_high),
                                    ),
                                    ButtonSegment(
                                      value: 'skip',
                                      label: Text('Skip Turn'),
                                      icon: Icon(Icons.skip_next),
                                    ),
                                  ],
                                  selected: {_derbyTimeoutBehavior},
                                  onSelectionChanged: (Set<String> selection) {
                                    setState(() {
                                      _derbyTimeoutBehavior = selection.first;
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _derbyTimeoutBehavior == 'auto'
                                      ? 'Automatically assign next available slot if time runs out'
                                      : 'Skip to next manager if time runs out (manager picks from remaining slots later)',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Draft Summary
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        _buildSummaryRow('Timer Mode', _timerMode == 'traditional' ? 'Traditional' : 'Chess Timer'),
                        if (_timerMode == 'traditional')
                          _buildSummaryRow('Pick Timer', _getTimerSummary())
                        else
                          _buildSummaryRow('Team Budget', _getTimeBudgetDisplay()),
                        _buildSummaryRow('Rounds', '$_rounds'),
                        _buildSummaryRow('Total Picks',
                            '${_rounds * 12}'), // Assuming 12 teams
                        if (_autoPauseEnabled)
                          _buildSummaryRow(
                              'Auto-Pause',
                              '${_autoPauseStartTime.format(context)} - ${_autoPauseEndTime.format(context)}'),
                        if (_derbyEnabled) ...[
                          _buildSummaryRow('Derby', 'Enabled'),
                          _buildSummaryRow('Derby Timer', _getDerbyTimerDisplay()),
                          _buildSummaryRow('On Timeout', _derbyTimeoutBehavior == 'auto' ? 'Auto-Assign' : 'Skip'),
                        ],
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

  String _getTimeBudgetDisplay() {
    final hours = _teamTimeBudgetMinutes ~/ 60;
    final minutes = _teamTimeBudgetMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  String _getDerbyTimerDisplay() {
    final minutes = _derbyTimeLimitSeconds ~/ 60;
    final seconds = _derbyTimeLimitSeconds % 60;

    if (minutes > 0 && seconds > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildPresetButton(int minutes, String label) {
    final isSelected = _teamTimeBudgetMinutes == minutes;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          setState(() => _teamTimeBudgetMinutes = minutes);
        }
      },
      backgroundColor: isSelected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  String _getDraftTypeDescription() {
    switch (_draftType) {
      case 'snake':
        return 'Traditional snake draft with alternating pick order';
      case 'linear':
        return 'Same pick order every round';
      case 'auction':
        return 'Live auction - all teams online at once, one player at a time';
      case 'slow_auction':
        return 'Asynchronous auction - multiple players nominated simultaneously over days/weeks';
      default:
        return '';
    }
  }

  List<Widget> _buildAuctionSettings() {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Starting Budget
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Starting Budget',
                  prefixText: '\$',
                  helperText: 'How much money each team starts with',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _startingBudget.toString())
                  ..selection = TextSelection.collapsed(offset: _startingBudget.toString().length),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    setState(() => _startingBudget = parsed);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Min Bid
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Minimum Bid',
                  prefixText: '\$',
                  helperText: 'Minimum bid increment',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _minBid.toString())
                  ..selection = TextSelection.collapsed(offset: _minBid.toString().length),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    setState(() => _minBid = parsed);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Reserve Budget Toggle
              SwitchListTile(
                title: const Text('Reserve \$1 Per Roster Slot'),
                subtitle: const Text('Prevents teams from running out of money'),
                value: _reserveBudgetPerSlot,
                onChanged: (value) {
                  setState(() => _reserveBudgetPerSlot = value);
                },
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),

      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nomination Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              if (_draftType == 'auction') ...[
                // Pick Time (for regular auction)
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Bidding Time',
                    suffixText: 'seconds',
                    helperText: 'Time limit for each player nomination',
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _pickTimeSeconds.toString())
                    ..selection = TextSelection.collapsed(offset: _pickTimeSeconds.toString().length),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      setState(() => _pickTimeSeconds = parsed);
                    }
                  },
                ),
              ],

              if (_draftType == 'slow_auction') ...[
                // Nominations Per Manager
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nominations Per Manager',
                    helperText: 'How many nominations each manager can have active at once (3-5 recommended)',
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _nominationsPerManager.toString())
                    ..selection = TextSelection.collapsed(offset: _nominationsPerManager.toString().length),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      setState(() => _nominationsPerManager = parsed);
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Nomination Timer
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nomination Timer',
                    suffixText: 'hours',
                    helperText: 'Hours until player is awarded (resets with new bid)',
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _nominationTimerHours.toString())
                    ..selection = TextSelection.collapsed(offset: _nominationTimerHours.toString().length),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      setState(() => _nominationTimerHours = parsed);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}
