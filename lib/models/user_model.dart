class User {
  final int id;
  final String username;
  final String email;
  final String? phoneNumber;
  final bool isPhoneVerified;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.phoneNumber,
    required this.isPhoneVerified,
  });

  // Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
    );
  }

  // Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'is_phone_verified': isPhoneVerified,
    };
  }

  // Copy with method for updating user data
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? phoneNumber,
    bool? isPhoneVerified,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
    );
  }
}
