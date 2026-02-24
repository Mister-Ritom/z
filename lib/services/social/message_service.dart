import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/models/message_model.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';

/// MessageService — Supabase-backed messaging with Realtime support.
class MessageService {
  final SupabaseClient _db = Database.client;

  // ─── CONVERSATIONS ─────────────────────────────────────

  String getConversationId(List<String> userIds) {
    final sorted = List<String>.from(userIds)..sort();
    return sorted.join('_');
  }

  Stream<List<ConversationModel>> getConversations(String userId) {
    return _db
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((data) {
          return data
              .where((d) {
                final recipients = List<String>.from(d['recipients'] ?? []);
                return recipients.contains(userId);
              })
              .map((d) => ConversationModel.fromMap(d))
              .toList();
        });
  }

  // ─── MESSAGES ──────────────────────────────────────────

  Future<MessageModel> sendMessage({
    required String senderId,
    required List<String> recipients,
    required String text,
    String? referenceId,
    List<String>? mediaUrls,
  }) async {
    try {
      final conversationId = referenceId ?? getConversationId(recipients);

      final data = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'recipient_ids': recipients,
        'text': text,
        'media_urls': mediaUrls ?? [],
        'is_pending': false,
        'is_deleted': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _db.from('messages').insert(data).select().single();
      final message = MessageModel.fromMap(result);

      // Update or create conversation
      await _db.from('conversations').upsert({
        'id': conversationId,
        'recipients': recipients,
        'last_message':
            text.isNotEmpty
                ? text
                : (mediaUrls?.isNotEmpty ?? false)
                ? '📎 Media'
                : '',
        'last_message_at': DateTime.now().toIso8601String(),
        'last_message_sender': senderId,
        'unread_count': 1,
        'is_deleted': false,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      return message;
    } catch (e, st) {
      AppLogger.error(
        'MessageService',
        'Failed to send message',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<MessageModel> addPendingMessage({
    required String senderId,
    required List<String> recipients,
    required String text,
    required String conversationId,
    required List<String> localPaths,
  }) async {
    final message = MessageModel(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      recipientsIds: recipients,
      text: text,
      mediaUrls: localPaths, // Placeholder for local display
      createdAt: DateTime.now(),
      isRead: false,
      isPending: true,
      isDeleted: false,
    );

    // Persist pending message so it's visible in the stream
    await _db.from('messages').insert({
      'id': message.id,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'recipient_ids': message.recipientsIds,
      'text': message.text,
      'media_urls': message.mediaUrls,
      'is_pending': true,
      'is_deleted': false,
      'created_at': message.createdAt.toIso8601String(),
    });

    return message;
  }

  Future<void> finalizePendingMessage({
    required String messageId,
    required List<String> uploadedUrls,
  }) async {
    try {
      await _db
          .from('messages')
          .update({'media_urls': uploadedUrls, 'is_pending': false})
          .eq('id', messageId);

      AppLogger.info('MessageService', 'Finalized pending message: $messageId');
    } catch (e, st) {
      AppLogger.error(
        'MessageService',
        'Failed to finalize message',
        error: e,
        stackTrace: st,
      );
    }
  }

  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .map((data) => data.map((d) => MessageModel.fromMap(d)).toList());
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _db
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId);

      await _db
          .from('conversations')
          .update({'is_read': true, 'unread_count': 0})
          .eq('id', conversationId);
    } catch (e, st) {
      AppLogger.error(
        'MessageService',
        'Failed to mark as read',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _db
          .from('messages')
          .update({'is_deleted': true})
          .eq('id', messageId);
    } catch (e, st) {
      AppLogger.error(
        'MessageService',
        'Failed to delete message',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _db
          .from('conversations')
          .update({'is_deleted': true})
          .eq('id', conversationId);
    } catch (e, st) {
      AppLogger.error(
        'MessageService',
        'Failed to delete conversation',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> isMessagingBlocked({
    required String senderId,
    required List<String> recipients,
  }) async {
    try {
      for (final recipientId in recipients) {
        final block =
            await _db
                .from('blocks')
                .select('id')
                .or('blocker_id.eq.$senderId,blocker_id.eq.$recipientId')
                .inFilter('block_type', ['user', 'messaging'])
                .or(
                  'blocked_user_id.eq.$senderId,blocked_user_id.eq.$recipientId',
                )
                .maybeSingle();
        if (block != null) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
