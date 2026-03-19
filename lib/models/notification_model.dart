class NotificationModel {
  final String id;
  final String userId;
  final String fromUserId;
  final NotificationType type;
  final String? zapId;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.fromUserId,
    required this.type,
    this.zapId,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      fromUserId: map['from_user_id'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.like,
      ),
      zapId: map['zap_id'],
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'].toString())
              : DateTime.now(),
      isRead: map['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'from_user_id': fromUserId,
      'type': type.toString().split('.').last,
      'zap_id': zapId,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }
}

enum NotificationType { like, rezap, reply, follow, mention, message }
