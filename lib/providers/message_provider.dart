import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/utils/constants.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';

final messageServiceProvider = Provider<MessageService>((ref) {
  return MessageService();
});

final conversationsProvider =
    StreamProvider.family<List<ConversationModel>, String>((ref, userId) {
      final messageService = ref.watch(messageServiceProvider);
      return messageService.getConversations(userId);
    });

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  key,
) {
  final recipients = key.split('_');
  final messageService = ref.watch(messageServiceProvider);
  return messageService.getMessages(recipients);
});

final unreadMessageCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return FirebaseFirestore.instance
      .collection(AppConstants.messagesCollection)
      .where('receiverIds', arrayContains: userId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});
