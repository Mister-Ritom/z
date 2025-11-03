import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:z/models/notification_model.dart';
import 'package:z/utils/helpers.dart';
import '../../models/user_model.dart';
import '../../providers/message_provider.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUser,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final messageService = ref.read(messageServiceProvider);
      await messageService.sendMessage(
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        text: text,
      );
      Helpers.createNotification(
        userId: widget.otherUserId,
        fromUserId: widget.currentUserId,
        type: NotificationType.message,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _markReadMessages() {
    final messageService = ref.read(messageServiceProvider);
    unawaited(
      messageService.markMessagesAsRead(
        widget.currentUserId,
        widget.otherUserId,
        widget.currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      messagesProvider((widget.currentUserId, widget.otherUserId)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  widget.otherUser.profilePictureUrl != null
                      ? CachedNetworkImageProvider(
                        widget.otherUser.profilePictureUrl!,
                      )
                      : null,
              child:
                  widget.otherUser.profilePictureUrl == null
                      ? Text(widget.otherUser.displayName[0].toUpperCase())
                      : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUser.displayName),
                  if (widget.otherUser.isVerified)
                    const Icon(Icons.verified, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    _markReadMessages();
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;
                    return MessageBubble(message: message, isMe: isMe);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                log("Error $error");
                return Center(child: Text('Error: $error'));
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: () {
                    // Pick image
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
