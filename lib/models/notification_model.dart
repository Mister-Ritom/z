class NotificationModel {
  final String id;
  final String userId; // User who receives the notification
  final String fromUserId; // User who triggered the notification
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
      userId: map['userId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.like,
      ),
      zapId: map['zapId'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fromUserId': fromUserId,
      'type': type.toString().split('.').last,
      'zapId': zapId,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }
}

enum NotificationType { like, rezap, reply, follow, mention, message }
