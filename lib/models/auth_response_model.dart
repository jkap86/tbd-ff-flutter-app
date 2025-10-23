import 'user_model.dart';

class AuthResponse {
  final bool success;
  final String message;
  final AuthData? data;

  AuthResponse({
    required this.success,
    required this.message,
    this.data,
  });

  // Create AuthResponse from JSON
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: json['data'] != null ? AuthData.fromJson(json['data']) : null,
    );
  }

  // Convert AuthResponse to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
    };
  }
}

class AuthData {
  final User user;
  final String token;

  AuthData({
    required this.user,
    required this.token,
  });

  // Create AuthData from JSON
  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      user: User.fromJson(json['user']),
      token: json['token'] as String,
    );
  }

  // Convert AuthData to JSON
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
    };
  }
}

// Error response model
class ErrorResponse {
  final bool success;
  final String message;

  ErrorResponse({
    required this.success,
    required this.message,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? 'An error occurred',
    );
  }
}
