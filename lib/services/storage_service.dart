import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  final _secureStorage = const FlutterSecureStorage();

  // Save token to secure storage (or SharedPreferences on web/Windows)
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (e) {
      // Fallback to SharedPreferences if secure storage isn't available (web/Windows)
      print('[StorageService] Secure storage unavailable, using SharedPreferences: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }
  }

  // Get token from secure storage (or SharedPreferences on web/Windows)
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      // Fallback to SharedPreferences if secure storage isn't available
      print('[StorageService] Secure storage unavailable, using SharedPreferences: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
  }

  // Save user info to local storage
  Future<void> saveUserInfo(int userId, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
  }

  // Get user ID from local storage
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  // Get username from local storage
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // Check if user is logged in (has token)
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all stored data (logout)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenKey); // Also clear from SharedPreferences

    // Clear token from secure storage
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (e) {
      // Ignore errors if secure storage isn't available
      print('[StorageService] Could not clear secure storage: $e');
    }
  }
}
