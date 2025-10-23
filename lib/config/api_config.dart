class ApiConfig {
  // Base URL for your backend API
  // Change this to your actual backend URL
  // For Android emulator: http://10.0.2.2:3000
  // For iOS simulator: http://localhost:3000
  // For physical device: http://YOUR_COMPUTER_IP:3000
  static const String baseUrl = 'https://tbd-ff-6abbe03bd5b6.herokuapp.com';

  // API endpoints
  static const String register = '$baseUrl/api/auth/register';
  static const String login = '$baseUrl/api/auth/login';
  static const String profile = '$baseUrl/api/profile';

  // Headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
      };

  static Map<String, String> getAuthHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
}
