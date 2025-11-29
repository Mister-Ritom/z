import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/utils/constants.dart';
import '../services/social/message_service.dart';
import '../models/message_model.dart';
import 'auth_provider.dart';

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
  // Use ||| as separator - this must never appear in user IDs
  const separator = '|||';
  final recipients = key.split(separator);
  final messageService = ref.watch(messageServiceProvider);
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final currentUserId = currentUser?.uid ?? recipients.first;
  return messageService.getMessages(recipients, currentUserId);
});

final unreadMessageCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return FirebaseFirestore.instance
      .collection(AppConstants.messagesCollection)
      .where('recipientsIds', arrayContains: userId)
      .where('senderId', isNotEqualTo: userId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});
