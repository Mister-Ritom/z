import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../utils/constants.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get or create conversation ID
  String _getConversationId(String user1Id, String user2Id) {
    final ids = [user1Id, user2Id]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Send a message
  Future<MessageModel> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    List<String>? imageUrls,
    String? videoUrl,
  }) async {
    try {
      final conversationId = _getConversationId(senderId, receiverId);

      final message = MessageModel(
        id: _firestore.collection(AppConstants.messagesCollection).doc().id,
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        createdAt: DateTime.now(),
      );

      // Save message
      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(message.id)
          .set(message.toMap());

      // Update conversation
      final userIds = [senderId, receiverId]..sort();
      await _firestore.collection('conversations').doc(conversationId).set({
        'id': conversationId,
        'user1Id': userIds[0],
        'user2Id': userIds[1],
        'lastMessage': text,
        'lastMessageAt': DateTime.now(),
        'unreadCount': FieldValue.increment(1),
        'isDeleted': false,
        'isRead': false,
        'createdAt': DateTime.now(),
        'lastMessageSender': senderId,
      }, SetOptions(merge: true));

      return message;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get messages for a conversation
  Stream<List<MessageModel>> getMessages(String user1Id, String user2Id) {
    final conversationId = _getConversationId(user1Id, user2Id);

    return _firestore
        .collection(AppConstants.messagesCollection)
        .where('conversationId', isEqualTo: conversationId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.messagesPerPage)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) =>
                        MessageModel.fromMap({'id': doc.id, ...doc.data()}),
                  )
                  .toList()
                  .reversed
                  .toList(),
        );
  }

  // Get conversations for a user
  Stream<List<ConversationModel>> getConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('user1Id', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot1) async {
          final list1 =
              snapshot1.docs.map((doc) {
                final data = doc.data();
                return ConversationModel.fromMap({'id': doc.id, ...data});
              }).toList();

          final snapshot2 =
              await _firestore
                  .collection('conversations')
                  .where('user2Id', isEqualTo: userId)
                  .get();

          final list2 =
              snapshot2.docs.map((doc) {
                final data = doc.data();
                return ConversationModel.fromMap({'id': doc.id, ...data});
              }).toList();

          return [...list1, ...list2]
            ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(
    String user1Id,
    String user2Id,
    String currentUserId,
  ) async {
    try {
      final conversationId = _getConversationId(user1Id, user2Id);

      // Fetch conversation details first
      final conversationDoc =
          await _firestore
              .collection('conversations')
              .doc(conversationId)
              .get();

      if (!conversationDoc.exists) return;

      final conversationData = conversationDoc.data()!;
      final lastMessageSender = conversationData['lastMessageSender'];

      // Only mark as read if the last message was NOT sent by the current user
      if (lastMessageSender != null && lastMessageSender != currentUserId) {
        final batch = _firestore.batch();

        final messages =
            await _firestore
                .collection(AppConstants.messagesCollection)
                .where('conversationId', isEqualTo: conversationId)
                .where('receiverId', isEqualTo: currentUserId)
                .where('isRead', isEqualTo: false)
                .get();

        for (final doc in messages.docs) {
          batch.update(doc.reference, {'isRead': true});
        }

        await batch.commit();

        // Reset unread count and set isRead true
        await _firestore.collection('conversations').doc(conversationId).update(
          {'unreadCount': 0, 'isRead': true},
        );
        await markMessageNotificationsAsRead(
          currentUserId: currentUserId,
          otherUserId: user2Id,
        );
      }
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  Future<void> markMessageNotificationsAsRead({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(AppConstants.notificationsCollection)
              .where('userId', isEqualTo: currentUserId)
              .where('fromUserId', isEqualTo: otherUserId)
              .where('type', isEqualTo: "message")
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      throw Exception('❌ Failed to mark message notifications as read: $e');
    }
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({'isDeleted': true});
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }
}
