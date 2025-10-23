class ApiConfig {
  // Base URL for your backend API
  // Change this to your actual backend URL
  // For Android emulator: http://10.0.2.2:3000
  // For iOS simulator: http://localhost:3000
  // For physical device: http://YOUR_COMPUTER_IP:3000
  static const String baseUrl = 'https://tbd-ff-6abbe03bd5b6.herokuapp.com';

  // API endpoints - Auth
  static const String register = '$baseUrl/api/auth/register';
  static const String login = '$baseUrl/api/auth/login';
  static const String profile = '$baseUrl/api/profile';

  // API endpoints - Leagues
  static const String leaguesCreate = '$baseUrl/api/leagues/create';
  static const String leaguesPublic = '$baseUrl/api/leagues/public';
  static const String leaguesUser = '$baseUrl/api/leagues/user';
  static const String leaguesDetail = '$baseUrl/api/leagues';
  static const String leaguesJoin = '$baseUrl/api/leagues';
  static const String leaguesUpdate = '$baseUrl/api/leagues';
  static const String leaguesIsCommissioner = '$baseUrl/api/leagues';
  static const String leaguesTransferCommissioner = '$baseUrl/api/leagues';
  static const String leaguesRemoveMember = '$baseUrl/api/leagues';
  static const String leaguesStats = '$baseUrl/api/leagues';

  // API endpoints - Invites
  static const String invitesSend = '$baseUrl/api/invites/send';
  static const String invitesUser = '$baseUrl/api/invites/user';
  static const String invitesAccept = '$baseUrl/api/invites';
  static const String invitesDecline = '$baseUrl/api/invites';

  // Headers
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
      };

  static Map<String, String> getAuthHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
}
