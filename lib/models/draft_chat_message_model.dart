class DraftChatMessage {
  final int id;
  final int draftId;
  final int userId;
  final String message;
  final String messageType; // 'chat', 'system', 'pick_announcement'
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  // Extended field from join query
  final String? username;

  DraftChatMessage({
    required this.id,
    required this.draftId,
    required this.userId,
    required this.message,
    required this.messageType,
    this.metadata,
    required this.createdAt,
    this.username,
  });

  factory DraftChatMessage.fromJson(Map<String, dynamic> json) {
    return DraftChatMessage(
      id: json['id'] as int,
      draftId: json['draft_id'] as int,
      userId: json['user_id'] as int,
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
      'draft_id': draftId,
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
  bool get isPickAnnouncement => messageType == 'pick_announcement';

  String get displayUsername => username ?? 'User $userId';
}
