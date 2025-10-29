class LeagueChatMessage {
  final int id;
  final int leagueId;
  final int? userId; // Nullable for system messages
  final String message;
  final String messageType; // 'chat', 'system'
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  // Extended field from join query
  final String? username;

  LeagueChatMessage({
    required this.id,
    required this.leagueId,
    this.userId, // Optional for system messages
    required this.message,
    required this.messageType,
    this.metadata,
    required this.createdAt,
    this.username,
  });

  factory LeagueChatMessage.fromJson(Map<String, dynamic> json) {
    return LeagueChatMessage(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      userId: json['user_id'] as int?,
      message: json['message'] as String,
      messageType: json['message_type'] as String? ?? 'chat',
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'user_id': userId,
      'message': message,
      'message_type': messageType,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'username': username,
    };
  }

  bool get isChat => messageType == 'chat';
  bool get isSystem => messageType == 'system';

  String get displayUsername => username ?? (userId != null ? 'User $userId' : 'System');
}
