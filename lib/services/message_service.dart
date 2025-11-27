import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../utils/constants.dart';
import 'firebase_analytics_service.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use ||| as separator - this must never appear in user IDs
  static const String _conversationSeparator = '|||';

  String _getConversationId(List<String> recipients) {
    final sortedIds = [...recipients]..sort();
    return sortedIds.join(_conversationSeparator);
  }

  // ✅ NEW: Add a pending message immediately to Firestore
  Future<MessageModel> addPendingMessage({
    required String senderId,
    required List<String> recipients,
    required String text,
    required String conversationId,
    List<String>? localPaths,
  }) async {
    try {
      final message = MessageModel(
        id: _firestore.collection(AppConstants.messagesCollection).doc().id,
        conversationId: conversationId,
        senderId: senderId,
        recipientsIds: recipients,
        text: text,
        mediaUrls: localPaths,
        isPending: true,
        isDeleted: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(message.id)
          .set(message.toMap());

      return message;
    } catch (e) {
      throw Exception('Failed to add pending message: $e');
    }
  }

  // ✅ NEW: Finalize a pending message after upload finishes
  Future<void> finalizePendingMessage({
    required String messageId,
    required List<String> uploadedUrls,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({
            'isPending': false,
            'mediaUrls': uploadedUrls,
            'updatedAt': DateTime.now(),
          });
    } catch (e) {
      throw Exception('Failed to finalize pending message: $e');
    }
  }

  // ✅ Existing sendMessage (unchanged)
  Future<MessageModel> sendMessage({
    required String senderId,
    required List<String> recipients,
    required String text,
    String? referenceId,
    List<String>? mediaUrls,
    String? videoUrl,
  }) async {
    try {
      final conversationId = referenceId ?? _getConversationId(recipients);

      final message = MessageModel(
        id: _firestore.collection(AppConstants.messagesCollection).doc().id,
        conversationId: conversationId,
        senderId: senderId,
        recipientsIds: recipients,
        text: text,
        mediaUrls: mediaUrls,
        isPending: false,
        isDeleted: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(message.id)
          .set(message.toMap());

      await _firestore.collection('conversations').doc(conversationId).set({
        'id': conversationId,
        'recipients': recipients,
        'lastMessage':
            text.isNotEmpty
                ? text
                : (mediaUrls?.isNotEmpty ?? false)
                ? '📎 Media'
                : '',
        'lastMessageAt': DateTime.now(),
        'unreadCount': FieldValue.increment(1),
        'isDeleted': false,
        'isRead': false,
        'createdAt': DateTime.now(),
        'lastMessageSender': senderId,
      }, SetOptions(merge: true));

      // Track message sent in Firebase Analytics
      await FirebaseAnalyticsService.logMessageSent();

      return message;
    } catch (e, stackTrace) {
      // Report error to Crashlytics
      await FirebaseAnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Failed to send message',
        fatal: false,
      );
      throw Exception('Failed to send message: $e');
    }
  }

  // ✅ Everything else remains unchanged below...
  Stream<List<MessageModel>> getMessages(
    List<String> recipients,
    String currentUserId,
  ) {
    final conversationId = _getConversationId(recipients);

    return _firestore
        .collection(AppConstants.messagesCollection)
        .where('recipientsIds', arrayContains: currentUserId)
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

  Stream<List<ConversationModel>> getConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('recipients', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ConversationModel.fromMap({
                      'id': doc.id,
                      ...doc.data(),
                    }),
                  )
                  .toList()
                ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt)),
        );
  }

  Future<void> markMessagesAsRead(
    List<String> recipients,
    String currentUserId,
  ) async {
    try {
      final conversationId = _getConversationId(recipients);

      final conversationDoc =
          await _firestore
              .collection('conversations')
              .doc(conversationId)
              .get();

      if (!conversationDoc.exists) return;

      final conversationData = conversationDoc.data()!;
      final lastMessageSender = conversationData['lastMessageSender'];

      if (lastMessageSender != null && lastMessageSender != currentUserId) {
        final batch = _firestore.batch();

        final messages =
            await _firestore
                .collection(AppConstants.messagesCollection)
                .where('recipientsIds', arrayContains: currentUserId)
                .where('conversationId', isEqualTo: conversationId)
                .where('isRead', isEqualTo: false)
                .get();

        for (final doc in messages.docs) {
          batch.update(doc.reference, {'isRead': true});
        }

        await batch.commit();

        await _firestore.collection('conversations').doc(conversationId).update(
          {'unreadCount': 0, 'isRead': true},
        );

        for (final recipient in recipients) {
          if (recipient != currentUserId) {
            await markMessageNotificationsAsRead(
              currentUserId: currentUserId,
              otherUserId: recipient,
            );
          }
        }
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
}
