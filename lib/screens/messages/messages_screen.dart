import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/message_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import 'chat_screen.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final conversationsAsync = ref.watch(
      conversationsProvider(currentUser.uid),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Search conversations
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(child: Text('No messages yet'));
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];

              // Determine the "other user" by excluding the current user from recipients
              final otherUserId = conversation.recipients.firstWhere(
                (id) => id != currentUser.uid,
              );

              final userAsync = ref.watch(userProfileProvider(otherUserId));

              return userAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage:
                          user.profilePictureUrl != null
                              ? CachedNetworkImageProvider(
                                user.profilePictureUrl!,
                              )
                              : null,
                      child:
                          user.profilePictureUrl == null
                              ? Text(user.displayName[0].toUpperCase())
                              : null,
                    ),
                    title: Text(user.displayName),
                    subtitle: Text(
                      conversation.lastMessage ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            conversation.unreadCount > 0 &&
                                    conversation.lastMessageSender !=
                                        currentUser.uid
                                ? Theme.of(context).colorScheme.inverseSurface
                                : Colors.grey,
                        fontWeight:
                            conversation.unreadCount > 0 &&
                                    conversation.lastMessageSender !=
                                        currentUser.uid
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeago.format(conversation.lastMessageAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (conversation.unreadCount > 0 &&
                            conversation.lastMessageSender != currentUser.uid)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              conversation.unreadCount > 9
                                  ? '9+'
                                  : conversation.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: otherUserId,
                          ),
                        ),
                      );
                    },
                  );
                },
                loading:
                    () => const ListTile(
                      leading: CircularProgressIndicator(strokeWidth: 2),
                    ),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          log("Error getting convos", error: error, stackTrace: stack);
          return Center(child: Text('Error: $error'));
        },
      ),
    );
  }
}
