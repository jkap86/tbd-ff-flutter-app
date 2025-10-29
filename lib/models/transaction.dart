class Transaction {
  final int id;
  final int leagueId;
  final int rosterId;
  final String transactionType; // 'waiver', 'free_agent'
  final List<int> adds;
  final List<int> drops;
  final int? waiverBid;
  final DateTime processedAt;
  final String? username;

  Transaction({
    required this.id,
    required this.leagueId,
    required this.rosterId,
    required this.transactionType,
    required this.adds,
    required this.drops,
    this.waiverBid,
    required this.processedAt,
    this.username,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      leagueId: json['league_id'] as int,
      rosterId: json['roster_id'] as int,
      transactionType: json['transaction_type'] as String,
      adds: (json['adds'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      drops: (json['drops'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      waiverBid: json['waiver_bid'] as int?,
      processedAt: DateTime.parse(json['processed_at'] as String),
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'roster_id': rosterId,
      'transaction_type': transactionType,
      'adds': adds,
      'drops': drops,
      'waiver_bid': waiverBid,
      'processed_at': processedAt.toIso8601String(),
      'username': username,
    };
  }

  bool get isWaiver => transactionType == 'waiver';
  bool get isFreeAgent => transactionType == 'free_agent';

  String get typeDisplay {
    if (isWaiver) return 'Waiver';
    if (isFreeAgent) return 'Free Agent';
    return transactionType;
  }
}
