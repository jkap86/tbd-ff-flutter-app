import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  // Save user info to secure storage
  Future<void> saveUserInfo(int userId, String username) async {
    await _secureStorage.write(key: _userIdKey, value: userId.toString());
    await _secureStorage.write(key: _usernameKey, value: username);
  }

  // Get user ID from secure storage
  Future<int?> getUserId() async {
    final userIdStr = await _secureStorage.read(key: _userIdKey);
    return userIdStr != null ? int.tryParse(userIdStr) : null;
  }

  // Get username from secure storage
  Future<String?> getUsername() async {
    return await _secureStorage.read(key: _usernameKey);
  }

  // Check if user is logged in (has token)
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
