import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/supabase/database.dart';
import '../services/social/message_service.dart';
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
  conversationId,
) {
  final messageService = ref.watch(messageServiceProvider);
  return messageService.getMessages(conversationId);
});

final unreadMessageCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  // Use Supabase Realtime to track unread count
  return Database.client.from('conversations').stream(primaryKey: ['id']).map((
    data,
  ) {
    return data.where((d) {
      final recipients = List<String>.from(d['recipients'] ?? []);
      return recipients.contains(userId) &&
          d['is_read'] == false &&
          d['last_message_sender'] != userId;
    }).length;
  });
});
