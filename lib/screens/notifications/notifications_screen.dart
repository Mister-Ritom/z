import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final notificationsAsync = ref.watch(
      notificationsProvider(currentUser.uid),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final userAsync = ref.watch(
                userProfileProvider(notification.fromUserId),
              );

              return userAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          user.profilePictureUrl != null
                              ? NetworkImage(user.profilePictureUrl!)
                              : null,
                      child:
                          user.profilePictureUrl == null
                              ? Text(user.displayName[0].toUpperCase())
                              : null,
                    ),
                    title: Text(
                      _getNotificationText(notification.type, user.displayName),
                    ),
                    subtitle: Text(timeago.format(notification.createdAt)),
                    trailing: Icon(_getNotificationIcon(notification.type)),
                    onTap: () {
                      // Navigate to zap or profile
                    },
                  );
                },
                loading:
                    () => const ListTile(leading: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          log("Error: $error", stackTrace: stack);
          return Center(child: Text('Error: $error'));
        },
      ),
    );
  }

  String _getNotificationText(notificationType, String userName) {
    switch (notificationType.toString().split('.').last) {
      case 'like':
        return '$userName liked your zap';
      case 'rezap':
        return '$userName rezaped your zap';
      case 'reply':
        return '$userName replied to your zap';
      case 'follow':
        return '$userName followed you';
      case 'mention':
        return '$userName mentioned you';
      default:
        return 'New notification';
    }
  }

  IconData _getNotificationIcon(notificationType) {
    switch (notificationType.toString().split('.').last) {
      case 'like':
        return Icons.favorite;
      case 'rezap':
        return Icons.repeat;
      case 'reply':
        return Icons.chat_bubble;
      case 'follow':
        return Icons.person_add;
      case 'mention':
        return Icons.alternate_email;
      default:
        return Icons.notifications;
    }
  }
}
