import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

// Background message handler - must be top level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done
  await Firebase.initializeApp();

  print('[PushNotifications] Background message received:');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final StorageService _storage = StorageService();

  StreamController<RemoteMessage> _messageController = StreamController.broadcast();
  Stream<RemoteMessage> get messages => _messageController.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize push notifications
  Future<void> initialize() async {
    try {
      print('[PushNotifications] Initializing...');

      // Request permissions (iOS only)
      await _requestPermissions();

      // Get FCM token
      await _getToken();

      // Set up message handlers
      _setupMessageHandlers();

      // Configure foreground presentation options (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      print('[PushNotifications] Initialization complete');
    } catch (e) {
      print('[PushNotifications] Initialization error: $e');
    }
  }

  /// Request notification permissions (iOS only)
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('[PushNotifications] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('[PushNotifications] User denied permissions');
      }
    }
  }

  /// Get and register FCM token
  Future<void> _getToken() async {
    try {
      // Get token
      _fcmToken = await _messaging.getToken();
      print('[PushNotifications] FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        // Register token with backend
        await _registerTokenWithBackend(_fcmToken!);

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) async {
          print('[PushNotifications] Token refreshed: $newToken');
          _fcmToken = newToken;
          await _registerTokenWithBackend(newToken);
        });
      }
    } catch (e) {
      print('[PushNotifications] Error getting token: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      // Get auth token from storage
      final authToken = await _storage.getToken();
      if (authToken == null) {
        print('[PushNotifications] No auth token, skipping FCM registration');
        return;
      }

      // Determine device type
      String deviceType = Platform.isIOS ? 'ios' : 'android';

      // Generate device ID
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = '${deviceType}_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
      }

      // Register with backend
      final url = Uri.parse('${ApiConfig.baseUrl}/notifications/register-token');
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': token,
          'device_type': deviceType,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        print('[PushNotifications] Token registered with backend');
      } else {
        print('[PushNotifications] Failed to register token: ${response.body}');
      }
    } catch (e) {
      print('[PushNotifications] Error registering token: $e');
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[PushNotifications] Foreground message received:');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      // Emit to stream for UI to handle
      _messageController.add(message);

      // You can show a local notification here or handle in UI
      _showInAppNotification(message);
    });

    // Handle message tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[PushNotifications] Background message tapped:');
      print('Data: ${message.data}');

      // Navigate based on notification type
      _handleNotificationTap(message);
    });

    // Check if app was opened from terminated state via notification
    _checkInitialMessage();
  }

  /// Check if app was opened from notification
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      print('[PushNotifications] App opened from notification:');
      print('Data: ${initialMessage.data}');

      // Handle navigation after small delay to ensure app is ready
      Future.delayed(Duration(seconds: 1), () {
        _handleNotificationTap(initialMessage);
      });
    }
  }

  /// Show in-app notification (when app is in foreground)
  void _showInAppNotification(RemoteMessage message) {
    // This should be handled by your UI layer
    // For example, show a SnackBar or custom notification widget
    // You can emit an event or use a state management solution

    // Example: Using a global scaffold messenger key
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message.notification?.body ?? 'New notification'),
    //     action: SnackBarAction(
    //       label: 'View',
    //       onPressed: () => _handleNotificationTap(message),
    //     ),
    //   ),
    // );
  }

  /// Handle notification tap - navigate to relevant screen
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;

    // Navigate based on notification type
    if (data['type'] == 'draft_turn') {
      // Navigate to draft room
      final draftId = data['draft_id'];
      if (draftId != null) {
        // Use your navigation method
        // Navigator.pushNamed(context, '/draft/$draftId');
      }
    } else if (data['type'] == 'trade_proposed') {
      // Navigate to trade screen
      final tradeId = data['trade_id'];
      if (tradeId != null) {
        // Navigator.pushNamed(context, '/trade/$tradeId');
      }
    } else if (data['type'] == 'matchup_close') {
      // Navigate to matchup
      final matchupId = data['matchup_id'];
      if (matchupId != null) {
        // Navigator.pushNamed(context, '/matchup/$matchupId');
      }
    }
    // Add more cases as needed
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(Map<String, bool> preferences) async {
    try {
      final authToken = await _storage.getToken();
      if (authToken == null) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/notifications/preferences');
      final response = await http.put(
        url,
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(preferences),
      );

      if (response.statusCode == 200) {
        print('[PushNotifications] Preferences updated');
      } else {
        print('[PushNotifications] Failed to update preferences: ${response.body}');
      }
    } catch (e) {
      print('[PushNotifications] Error updating preferences: $e');
    }
  }

  /// Get notification preferences
  Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final authToken = await _storage.getToken();
      if (authToken == null) return {};

      final url = Uri.parse('${ApiConfig.baseUrl}/notifications/preferences');
      final response = await http.get(
        url,
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('[PushNotifications] Failed to get preferences: ${response.body}');
        return {};
      }
    } catch (e) {
      print('[PushNotifications] Error getting preferences: $e');
      return {};
    }
  }

  /// Deactivate push notifications (on logout)
  Future<void> deactivate() async {
    try {
      final authToken = await _storage.getToken();
      if (authToken == null) return;

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId != null) {
        final url = Uri.parse('${ApiConfig.baseUrl}/notifications/deactivate');
        final response = await http.post(
          url,
          headers: {
            ...ApiConfig.headers,
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'device_id': deviceId}),
        );

        if (response.statusCode == 200) {
          print('[PushNotifications] Deactivated');
        } else {
          print('[PushNotifications] Failed to deactivate: ${response.body}');
        }
      }
    } catch (e) {
      print('[PushNotifications] Error deactivating: $e');
    }
  }

  /// Clean up
  void dispose() {
    _messageController.close();
  }
}