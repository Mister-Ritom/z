class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String text;
  final List<String>? mediaUrls;
  final DateTime createdAt;
  final bool isRead;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.text,
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
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'mediaUrls': mediaUrls,
      'createdAt': createdAt,
      'isRead': isRead,
      'isDeleted': isDeleted,
    };
  }
}

class ConversationModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime lastMessageAt;
  final String? lastMessage;
  final String? lastMessageSender;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.lastMessageAt,
    this.lastMessageSender,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] ?? '',
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      lastMessageAt: map['lastMessageAt']?.toDate() ?? DateTime.now(),
      lastMessage: map['lastMessage'],
      unreadCount: map['unreadCount'] ?? 0,
      lastMessageSender: map["lastMessageSender"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'lastMessageAt': lastMessageAt,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'lastMessageSender': lastMessageSender,
    };
  }
}
