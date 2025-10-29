import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/waiver_provider.dart';
import '../../models/player_model.dart';
import '../../models/roster_model.dart';
import '../../config/api_config.dart';

class SubmitClaimDialog extends StatefulWidget {
  final int leagueId;
  final Roster userRoster;
  final Player player;
  final bool isFreeAgent;

  const SubmitClaimDialog({
    super.key,
    required this.leagueId,
    required this.userRoster,
    required this.player,
    this.isFreeAgent = false,
  });

  @override
  State<SubmitClaimDialog> createState() => _SubmitClaimDialogState();
}

class _SubmitClaimDialogState extends State<SubmitClaimDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bidController = TextEditingController();
  int? _selectedDropPlayerId;
  List<Player> _rosterPlayers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _faabBudget = 100; // Default budget

  @override
  void initState() {
    super.initState();
    _loadRosterPlayers();
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _loadRosterPlayers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) return;

      // Get FAAB budget from roster settings
      _faabBudget = widget.userRoster.settings?['faab_budget'] ?? 100;

      // Get roster with player details - use roster.id (database ID)
      final response = await http.get(
        Uri.parse('${ApiConfig.effectiveBaseUrl}/api/rosters/${widget.userRoster.id}/players'),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final playersData = data['data']['players'] as List;

        setState(() {
          _rosterPlayers = playersData.map((json) => Player.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading roster players: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final waiverProvider = Provider.of<WaiverProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated')),
        );
      }
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    bool success;
    if (widget.isFreeAgent) {
      // Add as free agent - use roster.id (database ID), not rosterId
      success = await waiverProvider.pickupFreeAgent(
        token: token,
        leagueId: widget.leagueId,
        rosterId: widget.userRoster.id,
        playerId: widget.player.id,
        dropPlayerId: _selectedDropPlayerId,
      );
    } else {
      // Submit waiver claim - use roster.id (database ID), not rosterId
      final bidAmount = int.tryParse(_bidController.text) ?? 0;
      success = await waiverProvider.submitClaim(
        token: token,
        leagueId: widget.leagueId,
        rosterId: widget.userRoster.id,
        playerId: widget.player.id,
        dropPlayerId: _selectedDropPlayerId,
        bidAmount: bidAmount,
      );
    }

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isFreeAgent
                  ? 'Successfully added ${widget.player.fullName}'
                  : 'Waiver claim submitted for ${widget.player.fullName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(waiverProvider.errorMessage ?? 'Failed to submit'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isFreeAgent ? 'Add Free Agent' : 'Submit Waiver Claim'),
      content: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player info
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                widget.player.position,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.player.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(widget.player.positionTeam),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bid amount (only for waivers)
                    if (!widget.isFreeAgent) ...[
                      Text(
                        'FAAB Budget: \$$_faabBudget',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bidController,
                        decoration: const InputDecoration(
                          labelText: 'Bid Amount',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                          helperText: 'Enter your FAAB bid',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a bid amount';
                          }
                          final bid = int.tryParse(value);
                          if (bid == null) {
                            return 'Please enter a valid number';
                          }
                          if (bid < 0) {
                            return 'Bid must be positive';
                          }
                          if (bid > _faabBudget) {
                            return 'Bid exceeds your budget';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Drop player selector
                    Text(
                      'Drop Player (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        helperText: 'Select a player to drop',
                      ),
                      value: _selectedDropPlayerId,
                      hint: const Text('None - Keep all players'),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._rosterPlayers.map((player) {
                          return DropdownMenuItem<int>(
                            value: player.id,
                            child: Text('${player.fullName} (${player.position})'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDropPlayerId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _isLoading ? null : _submitClaim,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isFreeAgent ? 'Add Player' : 'Submit Claim'),
        ),
      ],
    );
  }
}
