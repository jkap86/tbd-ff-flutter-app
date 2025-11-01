import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _token;
  String? _errorMessage;

  // Getters
  AuthStatus get status => _status;
  User? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Check if user is already logged in (on app start)
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final isLoggedIn = await _storageService.isLoggedIn();

      if (isLoggedIn) {
        _token = await _storageService.getToken();
        final userId = await _storageService.getUserId();
        final username = await _storageService.getUsername();

        if (_token != null && userId != null && username != null) {
          // Create a minimal user object from stored data
          // In a real app, you might want to fetch full user data from API
          _user = User(
            id: userId,
            username: username,
            email: '', // Could fetch this from API if needed
            isPhoneVerified: false,
          );
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Error checking auth status';
    }

    notifyListeners();
  }

  // Register new user
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        username: username,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
      );

      if (response.success && response.data != null) {
        _user = response.data!.user;
        _token = response.data!.token;

        // Save to local storage
        await _storageService.saveToken(_token!);
        await _storageService.saveUserInfo(_user!.id, _user!.username);

        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Registration failed: ${e.toString()}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Login user
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (kDebugMode) {
      debugPrint('[AuthProvider] Login started');
    }
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        debugPrint('[AuthProvider] Calling AuthService.login()');
      }
      final response = await _authService.login(
        username: username,
        password: password,
      );

      if (kDebugMode) {
        debugPrint('[AuthProvider] Response received - success: ${response.success}, hasData: ${response.data != null}');
      }

      if (response.success && response.data != null) {
        _user = response.data!.user;
        _token = response.data!.token;

        if (kDebugMode) {
          debugPrint('[AuthProvider] User authenticated, token length: ${_token!.length}');
        }

        // Save to local storage
        if (kDebugMode) {
          debugPrint('[AuthProvider] Saving authentication data to secure storage');
        }
        await _storageService.saveToken(_token!);
        await _storageService.saveUserInfo(_user!.id, _user!.username);
        if (kDebugMode) {
          debugPrint('[AuthProvider] Storage complete');
        }

        _status = AuthStatus.authenticated;
        notifyListeners();
        if (kDebugMode) {
          debugPrint('[AuthProvider] Login successful');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('[AuthProvider] Login failed: ${response.message}');
        }
        _errorMessage = response.message;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AuthProvider] Login exception: $e');
        debugPrint('[AuthProvider] Stack trace: $stackTrace');
      }
      _errorMessage = 'Login failed: ${e.toString()}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    await _storageService.clearAll();
    _user = null;
    _token = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Dev tools method for quick user switching (debug mode only)
  Future<void> setAuthData({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    if (!kDebugMode) {
      debugPrint('[AuthProvider] setAuthData is only available in debug mode');
      return;
    }

    _token = token;
    _user = User.fromJson(userData);

    // Save to local storage
    await _storageService.saveToken(_token!);
    await _storageService.saveUserInfo(_user!.id, _user!.username);

    _status = AuthStatus.authenticated;
    _errorMessage = null;
    notifyListeners();

    debugPrint('[AuthProvider] Auth data set for user: ${_user!.username}');
  }
}
