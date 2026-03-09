import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../supabase/database.dart';

final notificationServiceProvider = Provider((ref) => Database.client);

final notificationsProvider =
    FutureProvider.family<List<NotificationModel>, String>((ref, userId) async {
      final db = ref.read(notificationServiceProvider);
      final data = await db
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .neq('type', 'message')
          .order('created_at', ascending: false)
          .limit(50);

      return data.map((d) => NotificationModel.fromMap(d)).toList();
    });

final unreadNotificationsCountProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  final db = ref.read(notificationServiceProvider);
  // Using head: true or similar if possible, but length is safe for now
  final data = await db
      .from('notifications')
      .select('id')
      .eq('user_id', userId)
      .eq('is_read', false)
      .neq('type', 'message');

  return data.length;
});

Future<void> markAllNotificationsAsRead(String userId) async {
  await Database.client
      .from('notifications')
      .update({'is_read': true})
      .eq('user_id', userId)
      .neq('type', 'message')
      .eq('is_read', false);
}
