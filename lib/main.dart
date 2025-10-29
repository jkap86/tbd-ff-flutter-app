import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/league_provider.dart';
import 'providers/invite_provider.dart';
import 'providers/draft_provider.dart';
import 'providers/matchup_provider.dart';
import 'providers/waiver_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';
import 'config/api_config.dart';

void main() {
  // Print API configuration in debug mode
  ApiConfig.printConfig();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LeagueProvider()),
        ChangeNotifierProvider(create: (_) => InviteProvider()),
        ChangeNotifierProvider(create: (_) => DraftProvider()),
        ChangeNotifierProvider(create: (_) => MatchupProvider()),
        ChangeNotifierProvider(create: (_) => WaiverProvider()),
      ],
      child: const MyAppContent(),
    );
  }
}

class MyAppContent extends StatelessWidget {
  const MyAppContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Wait for theme to load before showing app
        if (!themeProvider.isLoaded) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'HypeTrain',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E3A8A), // Dark blue
              primary: const Color(0xFF1E3A8A), // Dark blue
              secondary: const Color(0xFFFF6B35), // Bright orange
              tertiary: const Color(0xFF00D9FF), // Bright teal
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E3A8A), // Dark blue
              primary: const Color(0xFF2563EB), // Lighter blue for dark mode
              secondary: const Color(0xFFFF6B35), // Bright orange
              tertiary: const Color(0xFF00D9FF), // Bright teal
              brightness: Brightness.dark,
              surface: const Color(0xFF1F2937), // Dark gray
            ),
            scaffoldBackgroundColor: const Color(0xFF111827), // Dark gray/black
            useMaterial3: true,
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    // Check authentication status on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
    });

    // Only handle deep links on mobile platforms (not web)
    if (!kIsWeb) {
      _appLinks = AppLinks();

      // Handle initial deep link (when app is launched from link)
      _handleInitialLink();

      // Handle deep links while app is running
      _sub = _appLinks.uriLinkStream.listen((Uri uri) {
        if (mounted) {
          _handleDeepLink(uri);
        }
      }, onError: (err) {
        debugPrint('Deep link error: $err');
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null && mounted) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error handling initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('📱 Deep link received: $uri');

    // Handle reset-password link
    if (uri.path.contains('reset-password')) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        debugPrint('✅ Password reset token found: $token');
        // Navigate to reset password screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(token: token),
          ),
        );
      } else {
        debugPrint('❌ No token found in reset password link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading screen while checking auth status
        if (authProvider.status == AuthStatus.initial ||
            authProvider.status == AuthStatus.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Navigate based on authentication status
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
