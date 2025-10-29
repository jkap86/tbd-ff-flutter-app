import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/draft_provider.dart';
import '../providers/auth_provider.dart';
import '../models/draft_order_model.dart';

class TimeManagementDialog extends StatefulWidget {
  final DraftOrder roster;

  const TimeManagementDialog({
    super.key,
    required this.roster,
  });

  @override
  State<TimeManagementDialog> createState() => _TimeManagementDialogState();
}

class _TimeManagementDialogState extends State<TimeManagementDialog> {
  String _operation = 'add'; // 'add' or 'remove'
  double _adjustmentMinutes = 5.0;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final draftProvider = Provider.of<DraftProvider>(context);
    final currentTimeRemaining = draftProvider.getRosterTimeRemaining(widget.roster.rosterId);

    return AlertDialog(
      title: const Text('Manage Team Time'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Team info
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.roster.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.hourglass_bottom, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Current Time: ${_formatTime(currentTimeRemaining ?? 0)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Operation selector
            Text(
              'Operation',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'add',
                  label: Text('Add Time'),
                  icon: Icon(Icons.add, size: 18),
                ),
                ButtonSegment(
                  value: 'remove',
                  label: Text('Remove Time'),
                  icon: Icon(Icons.remove, size: 18),
                ),
              ],
              selected: {_operation},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _operation = selection.first;
                });
              },
            ),
            const SizedBox(height: 20),

            // Adjustment amount
            Text(
              'Adjustment Amount',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_adjustmentMinutes.toInt()} minutes',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          _operation == 'add' ? '+' : '-',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _operation == 'add' ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _adjustmentMinutes,
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '${_adjustmentMinutes.toInt()} min',
                      onChanged: (value) {
                        setState(() {
                          _adjustmentMinutes = value;
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 min',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text('60 min',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Result preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _operation == 'add'
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _operation == 'add' ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Time:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    _formatTime(_calculateNewTime(currentTimeRemaining)),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _operation == 'add' ? Colors.green : Colors.red,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }

  int _calculateNewTime(int? currentTime) {
    if (currentTime == null) return 0;

    final adjustmentSeconds = (_adjustmentMinutes * 60).toInt();
    final newTime = _operation == 'add'
        ? currentTime + adjustmentSeconds
        : currentTime - adjustmentSeconds;

    return newTime.clamp(0, 999999); // Max time cap
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final draft = draftProvider.currentDraft;

    if (draft == null || authProvider.token == null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Missing draft or authentication'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final adjustmentSeconds = (_adjustmentMinutes * 60).toInt();
    final finalAdjustment =
        _operation == 'add' ? adjustmentSeconds : -adjustmentSeconds;

    final success = await draftProvider.adjustRosterTime(
      token: authProvider.token!,
      draftId: draft.id,
      rosterId: widget.roster.rosterId,
      adjustmentSeconds: finalAdjustment,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully ${_operation == 'add' ? 'added' : 'removed'} ${_adjustmentMinutes.toInt()} minutes ${_operation == 'add' ? 'to' : 'from'} ${widget.roster.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              draftProvider.errorMessage ?? 'Failed to adjust time',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
  }
}
