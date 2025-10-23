class UserSearchResult {
  final int id;
  final String username;
  final String email;
  final String? phoneNumber;
  final bool isPhoneVerified;

  UserSearchResult({
    required this.id,
    required this.username,
    required this.email,
    this.phoneNumber,
    required this.isPhoneVerified,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      phoneNumber: json['phone_number'] as String?,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
    );
  }
}
