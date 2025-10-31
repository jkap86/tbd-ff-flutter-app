import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
        // Check if response uses new format with success/message/data wrapper
        if (responseData['success'] != null && responseData['data'] != null) {
          return AuthResponse.fromJson(responseData);
        }

        // Old format: user and token at root level
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
      if (kDebugMode) {
        debugPrint('[AuthService] Login attempt initiated');
        debugPrint('[AuthService] API URL: ${ApiConfig.login}');
      }

      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (kDebugMode) {
        debugPrint('[AuthService] Response status: ${response.statusCode}');
        // Don't log response body or tokens
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Backend can return two formats:
        // 1. New format: { success: true, message: "...", data: { user: {...}, token: "..." } }
        // 2. Old format: { user: {...}, token: "..." }
        if (kDebugMode) {
          debugPrint('[AuthService] Creating AuthData from response');
        }

        try {
          // Check if response uses new format with success/message/data wrapper
          if (responseData['success'] != null && responseData['data'] != null) {
            if (kDebugMode) {
              debugPrint('[AuthService] Using new response format with data wrapper');
            }
            return AuthResponse.fromJson(responseData);
          }

          // Old format: user and token at root level
          if (responseData['user'] == null || responseData['token'] == null) {
            if (kDebugMode) {
              debugPrint('[AuthService] Missing user or token in response');
            }
            return AuthResponse(
              success: false,
              message: 'Invalid response format from server',
            );
          }

          if (kDebugMode) {
            debugPrint('[AuthService] Using old response format (user/token at root)');
          }
          final authData = AuthData.fromJson(responseData);
          if (kDebugMode) {
            debugPrint('[AuthService] AuthData created successfully');
          }

          return AuthResponse(
            success: true,
            message: 'Login successful',
            data: authData,
          );
        } catch (parseError, parseStackTrace) {
          if (kDebugMode) {
            debugPrint('[AuthService] Error parsing response: $parseError');
            debugPrint('[AuthService] Parse stack trace: $parseStackTrace');
            // Don't log response data structure as it may contain tokens
          }

          return AuthResponse(
            success: false,
            message: 'Error parsing server response: ${parseError.toString()}',
          );
        }
      } else {
        // Return error response
        if (kDebugMode) {
          debugPrint('[AuthService] Login failed with status ${response.statusCode}');
        }
        return AuthResponse(
          success: false,
          message: responseData['message'] ?? 'Login failed',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AuthService] Login error: $e');
        debugPrint('[AuthService] Stack trace: $stackTrace');
      }
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
