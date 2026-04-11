enum TransactionStatus { pending, cleared, rejected }

enum TransactionAppealStatus { none, pending, reviewed, not_applicable }

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type;
  final String? postId;
  final DateTime createdAt;
  final TransactionStatus status;
  final String? rejectionReason;
  final TransactionAppealStatus appealStatus;
  final String? engagementLogId;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.postId,
    required this.createdAt,
    required this.status,
    this.rejectionReason,
    required this.appealStatus,
    this.engagementLogId,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      postId: map['post_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      status: _parseStatus(map['status'] as String),
      rejectionReason: map['rejection_reason'] as String?,
      appealStatus: _parseAppealStatus(map['appeal_status'] as String),
      engagementLogId: map['engagement_log_id'] as String?,
    );
  }

  static TransactionStatus _parseStatus(String status) {
    switch (status) {
      case 'cleared':
        return TransactionStatus.cleared;
      case 'rejected':
        return TransactionStatus.rejected;
      case 'pending':
      default:
        return TransactionStatus.pending;
    }
  }

  static TransactionAppealStatus _parseAppealStatus(String status) {
    switch (status) {
      case 'pending':
        return TransactionAppealStatus.pending;
      case 'reviewed':
        return TransactionAppealStatus.reviewed;
      case 'not_applicable':
        return TransactionAppealStatus.not_applicable;
      case 'none':
      default:
        return TransactionAppealStatus.none;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'post_id': postId,
      'created_at': createdAt.toIso8601String(),
      'status': status.name,
      'rejection_reason': rejectionReason,
      'appeal_status': appealStatus.name,
      'engagement_log_id': engagementLogId,
    };
  }
}
