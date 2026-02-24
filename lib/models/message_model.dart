class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final List<String> recipientsIds;
  final String text;
  final List<String>? mediaUrls;
  final DateTime createdAt;
  final bool isRead;
  final bool isDeleted;
  final bool isPending;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientsIds,
    required this.text,
    this.isPending = false,
    this.mediaUrls,
    required this.createdAt,
    this.isRead = false,
    this.isDeleted = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      conversationId: map['conversation_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      recipientsIds: List<String>.from(map['recipient_ids'] ?? []),
      text: map['text'] ?? '',
      mediaUrls:
          map['media_urls'] != null
              ? List<String>.from(map['media_urls'])
              : null,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'].toString())
              : DateTime.now(),
      isRead: map['is_read'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      isPending: map['is_pending'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'recipient_ids': recipientsIds,
      'text': text,
      'media_urls': mediaUrls,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'is_deleted': isDeleted,
      'is_pending': isPending,
    };
  }
}

class ConversationModel {
  final String id;
  final List<String> recipients;
  final DateTime lastMessageAt;
  final String? lastMessage;
  final String? lastMessageSender;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.recipients,
    required this.lastMessageAt,
    this.lastMessageSender,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] ?? '',
      recipients: List<String>.from(map['recipients'] ?? []),
      lastMessageAt:
          map['last_message_at'] != null
              ? DateTime.parse(map['last_message_at'].toString())
              : DateTime.now(),
      lastMessage: map['last_message'],
      unreadCount: map['unread_count'] ?? 0,
      lastMessageSender: map['last_message_sender'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipients': recipients,
      'last_message_at': lastMessageAt.toIso8601String(),
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'last_message_sender': lastMessageSender,
    };
  }
}
