class WalletModel {
  final String id;
  final double availableBalance;
  final double pendingBalance;
  final DateTime updatedAt;

  WalletModel({
    required this.id,
    required this.availableBalance,
    required this.pendingBalance,
    required this.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as String,
      availableBalance: (map['available_balance'] as num).toDouble(),
      pendingBalance: (map['pending_balance'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'available_balance': availableBalance,
      'pending_balance': pendingBalance,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
