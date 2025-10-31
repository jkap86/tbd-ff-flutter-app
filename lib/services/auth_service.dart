import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_response_model.dart';

class AuthService {
  // Register new user
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Backend returns { user: {...}, token: "..." } format
        // Convert to expected AuthResponse format
        return AuthResponse(
          success: true,
          message: 'Registration successful',
          data: AuthData.fromJson(responseData),
        );
      } else {
        // Return error response
        return AuthResponse(
          success: false,
          message: responseData['message'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Login user
  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      print('[AuthService] Login attempt for username: $username');
      print('[AuthService] API URL: ${ApiConfig.login}');

      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('[AuthService] Response status code: ${response.statusCode}');
      print('[AuthService] Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      print('[AuthService] Parsed response data: $responseData');

      if (response.statusCode == 200) {
        // Backend returns { user: {...}, token: "..." } format
        // Convert to expected AuthResponse format
        print('[AuthService] Creating AuthData from response...');

        try {
          // Check if response has the expected structure
          if (responseData['user'] == null || responseData['token'] == null) {
            print('[AuthService] Missing user or token in response');
            return AuthResponse(
              success: false,
              message: 'Invalid response format from server',
            );
          }

          final authData = AuthData.fromJson(responseData);
          print('[AuthService] AuthData created successfully');

          return AuthResponse(
            success: true,
            message: 'Login successful',
            data: authData,
          );
        } catch (parseError, parseStackTrace) {
          print('[AuthService] Error parsing response: $parseError');
          print('[AuthService] Parse stack trace: $parseStackTrace');
          print('[AuthService] Response data structure: ${responseData.keys}');

          return AuthResponse(
            success: false,
            message: 'Error parsing server response: ${parseError.toString()}',
          );
        }
      } else {
        // Return error response
        print('[AuthService] Login failed with status ${response.statusCode}');
        return AuthResponse(
          success: false,
          message: responseData['message'] ?? 'Login failed',
        );
      }
    } catch (e, stackTrace) {
      print('[AuthService] Login error: $e');
      print('[AuthService] Stack trace: $stackTrace');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Get user profile (protected route example)
  Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.profile),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
