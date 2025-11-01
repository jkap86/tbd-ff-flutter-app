import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../config/dev_config.dart';
import '../services/dev_tools_service.dart';
import '../providers/auth_provider.dart';
import '../providers/league_provider.dart';
import '../models/league_model.dart';

class DevToolsWidget extends StatefulWidget {
  final League league;
  final VoidCallback? onUsersAdded;

  const DevToolsWidget({
    super.key,
    required this.league,
    this.onUsersAdded,
  });

  @override
  State<DevToolsWidget> createState() => _DevToolsWidgetState();
}

class _DevToolsWidgetState extends State<DevToolsWidget> {
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _lastResult;

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode || !DevConfig.showDevTools) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.developer_mode,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '🔧 Developer Tools (Debug Mode)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.orange[700],
                  ),
                ],
              ),
            ),
          ),

          // Content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Add Test Users Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.group_add),
                      label: Text(_isLoading
                          ? 'Adding Test Users...'
                          : 'Add Test Users (test1, test2, test3)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: _isLoading ? null : _addTestUsers,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Quick Switch User Buttons
                  Text(
                    'Quick Switch User:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final testUser in DevToolsService.testUsers)
                        OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _quickLogin(testUser['username']!),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[700],
                            side: BorderSide(color: Colors.orange[700]!),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            testUser['username']!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),

                  // Results Display
                  if (_lastResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _lastResult!,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    '⚠️ Debug mode only - Not visible in production',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addTestUsers() async {
    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final results = await DevToolsService.addTestUsersToLeague(
      leagueId: widget.league.id,
      currentUserToken: authProvider.token!,
    );

    setState(() {
      _isLoading = false;
      final successCount = results['success'].length;
      final failedCount = results['failed'].length;
      final errors = results['errors'] as List;

      _lastResult = 'Results:\n'
          '✅ Success: $successCount users added\n'
          '❌ Failed: $failedCount users\n'
          '${errors.isNotEmpty ? '\nErrors:\n${errors.join('\n')}' : ''}';
    });

    // Refresh the league data
    if (results['success'].isNotEmpty && widget.onUsersAdded != null) {
      widget.onUsersAdded!();
    }

    // Show snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${results['success'].length} test users. '
            '${results['failed'].isNotEmpty ? 'Failed: ${results['failed'].join(', ')}' : ''}',
          ),
          backgroundColor:
              results['failed'].isEmpty ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _quickLogin(String username) async {
    setState(() => _isLoading = true);

    final loginData = await DevToolsService.quickLoginAsTestUser(
      username: username,
    );

    if (loginData != null && mounted) {
      // Update auth provider with new user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setAuthData(
        token: loginData['token'],
        userData: loginData['user'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to $username'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload league data for new user
      final leagueProvider = Provider.of<LeagueProvider>(context, listen: false);
      await leagueProvider.loadUserLeagues(loginData['user']['id']);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to login as $username'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() => _isLoading = false);
  }
}