class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final List<String> receiverIds;
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
    required this.receiverIds,
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
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverIds: List<String>.from(map['receiverIds'] ?? []),
      text: map['text'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      isPending: map['isPending'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverIds': receiverIds,
      'text': text,
      'mediaUrls': mediaUrls,
      'createdAt': createdAt,
      'isRead': isRead,
      'isDeleted': isDeleted,
      'isPending': isPending,
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
      lastMessageAt: map['lastMessageAt']?.toDate() ?? DateTime.now(),
      lastMessage: map['lastMessage'],
      unreadCount: map['unreadCount'] ?? 0,
      lastMessageSender: map["lastMessageSender"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipients': recipients,
      'lastMessageAt': lastMessageAt,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'lastMessageSender': lastMessageSender,
    };
  }
}
