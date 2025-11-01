import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/responsive_container.dart';
import '../theme/app_theme.dart';
import '../widgets/common/themed_components.dart';
import '../widgets/chatbot/chatbot_widget.dart';
import '../services/push_notification_service.dart';
import 'profile_screen.dart';
import 'leagues_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PushNotificationService _pushService = PushNotificationService();

  @override
  void initState() {
    super.initState();
    // Initialize push notifications when home screen loads
    _initializePushNotifications();
  }

  Future<void> _initializePushNotifications() async {
    try {
      await _pushService.initialize();
      print('[HomeScreen] Push notifications initialized');
    } catch (e) {
      print('[HomeScreen] Error initializing push notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Theme toggle button
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Semantics(
                label: themeProvider.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                button: true,
                child: IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  ),
                  onPressed: () {
                    themeProvider.toggleTheme();
                  },
                  tooltip: themeProvider.isDarkMode
                      ? 'Switch to Light Mode'
                      : 'Switch to Dark Mode',
                ),
              );
            },
          ),
          // Profile button
          Semantics(
            label: 'Open Profile',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              tooltip: 'Profile',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final user = authProvider.user;

              if (user == null) {
                return const Center(
                  child: Text('No user data available'),
                );
              }

              return Column(
                children: [
                  // Logo banner - full width at top
                  Semantics(
                    label: 'Application logo',
                    image: true,
                    excludeSemantics: true,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        height: 240,
                        width: 540,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Scrollable content with ResponsiveContainer
                  Expanded(
                    child: ResponsiveContainer(
                      maxWidth: 800,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // My Leagues - Main feature
                            _buildHomeCard(
                              title: 'My Leagues',
                              subtitle: 'View and manage your leagues',
                              icon: Icons.sports_football,
                              accentColor: AppColors.primary,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const LeaguesScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            // My Players - Coming Soon
                            _buildComingSoonCard(
                              title: 'My Players',
                              icon: Icons.group,
                              accentColor: AppColors.secondary,
                            ),
                            const SizedBox(height: 16),
                            // My Leaguemates - Coming Soon
                            _buildComingSoonCard(
                              title: 'My Leaguemates',
                              icon: Icons.people,
                              accentColor: AppColors.warning,
                            ),
                            const SizedBox(height: 16),
                            // Trades - Coming Soon
                            _buildComingSoonCard(
                              title: 'Trades',
                              icon: Icons.swap_horiz,
                              accentColor: AppColors.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Chatbot overlay in bottom-right corner
          const Positioned(
            right: 16,
            bottom: 16,
            child: ChatbotWidget(),
          ),
        ],
      ),
    );
  }

  /// Builds an interactive home card
  Widget _buildHomeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: '$title. $subtitle',
      button: true,
      child: ThemedCard(
        onTap: onTap,
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 40,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: accentColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a coming soon placeholder card
  Widget _buildComingSoonCard({
    required String title,
    required IconData icon,
    required Color accentColor,
  }) {
    return Opacity(
      opacity: 0.6,
      child: ThemedCard(
        padding: const EdgeInsets.all(24),
        backgroundColor: AppColors.card.withValues(alpha: 0.5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 40,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontSize: 14,
                      color: accentColor.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
