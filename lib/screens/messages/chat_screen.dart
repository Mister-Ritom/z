import 'dart:async';
import 'dart:io';
import 'package:z/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:z/models/notification_model.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/utils/helpers.dart';
import '../../models/user_model.dart';
import '../../providers/message_provider.dart';
import '../../services/firebase_analytics_service.dart';
import 'package:z/widgets/messages/message_bubble.dart';

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
  final _picker = ImagePicker();
  List<XFile> _selectedFiles = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final List<XFile> files = await _picker.pickMultipleMedia();
      if (files.isNotEmpty) {
        setState(() => _selectedFiles = files);
        AppLogger.info(
          'ChatScreen',
          'Media picked successfully',
          data: {'fileCount': files.length},
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'ChatScreen',
        'Error picking media',
        error: e,
        stackTrace: st,
      );
    }
  }

  // Use ||| as separator - this must never appear in user IDs
  static const String _conversationSeparator = '|||';

  String _getConversationId() {
    final ids = [widget.currentUserId, widget.otherUserId]..sort();
    return ids.join(_conversationSeparator);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final hasFiles = _selectedFiles.isNotEmpty;
    if (text.isEmpty && !hasFiles) return;

    final referenceId = _getConversationId();

    if (hasFiles) {
      final messageService = ref.read(messageServiceProvider);
      final recipients = [widget.currentUserId, widget.otherUserId];

      final localFiles = [..._selectedFiles];
      setState(() => _selectedFiles = []);
      _messageController.clear();
      _scrollToBottom();
      final pendingMessage = await messageService.addPendingMessage(
        senderId: widget.currentUserId,
        recipients: recipients,
        text: text,
        conversationId: referenceId,
        localPaths: localFiles.map((e) => e.path).toList(),
      );

      final uploadNotifier = ref.read(uploadNotifierProvider.notifier);
      uploadNotifier.uploadFiles(
        files: localFiles,
        type: UploadType.document,
        referenceId: referenceId,
        onComplete: (urls) async {
          try {
            await messageService.finalizePendingMessage(
              messageId: pendingMessage.id,
              uploadedUrls: urls,
            );
            AppLogger.info(
              'ChatScreen',
              'Pending message finalized successfully',
              data: {'messageId': pendingMessage.id},
            );
          } catch (e, st) {
            AppLogger.error(
              'ChatScreen',
              'Error finalizing pending message',
              error: e,
              stackTrace: st,
              data: {'messageId': pendingMessage.id},
            );
          }
        },
      );
    } else {
      await _sendMessageText(referenceId: referenceId);
    }

    Helpers.createNotification(
      userId: widget.otherUserId,
      fromUserId: widget.currentUserId,
      type: NotificationType.message,
    );
  }

  Future<void> _sendMessageText({
    String? referenceId,
    List<String>? mediaUrls,
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty &&
        (_selectedFiles.isEmpty && (mediaUrls == null || mediaUrls.isEmpty))) {
      return;
    }

    try {
      final messageService = ref.read(messageServiceProvider);
      final recipients = [widget.currentUserId, widget.otherUserId];

      await messageService.sendMessage(
        referenceId: referenceId ?? _getConversationId(),
        senderId: widget.currentUserId,
        recipients: recipients,
        text: text,
        mediaUrls: mediaUrls,
      );

      if (text.isNotEmpty || (mediaUrls != null && mediaUrls.isNotEmpty)) {
        Helpers.createNotification(
          userId: widget.otherUserId,
          fromUserId: widget.currentUserId,
          type: NotificationType.message,
        );
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e, stackTrace) {
      // Report error to Crashlytics
      await FirebaseAnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Failed to send message in chat screen',
        fatal: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final screenHeight = MediaQuery.of(context).size.height;
    final extraOffset = maxScroll > screenHeight ? screenHeight * 0.2 : 0.0;
    final target = (maxScroll + extraOffset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
  }

  void _markReadMessages() {
    final messageService = ref.read(messageServiceProvider);
    unawaited(
      messageService.markMessagesAsRead([
        widget.currentUserId,
        widget.otherUserId,
      ], widget.currentUserId),
    );
  }

  Widget _buildPreview(XFile file) {
    final ext = file.path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(file.path),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.videocam, size: 40),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacityAlpha(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.insert_drive_file, size: 40),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = [widget.currentUserId, widget.otherUserId]..sort();
    final messagesAsync = ref.watch(
      messagesProvider(key.join(_conversationSeparator)),
    );

    return Scaffold(
      appBar: AppBar(
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
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollToBottom();
                  }
                });

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
                AppLogger.error(
                  'ChatScreen',
                  'Error loading messages',
                  error: error,
                  stackTrace: stack,
                  data: {
                    'currentUserId': widget.currentUserId,
                    'otherUserId': widget.otherUserId,
                  },
                );
                return Center(child: Text('Error: $error'));
              },
            ),
          ),
          if (_selectedFiles.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  return Stack(
                    children: [
                      _buildPreview(file),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFiles.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacityAlpha(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: _pickMedia,
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
