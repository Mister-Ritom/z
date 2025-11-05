import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:z/models/notification_model.dart';
import 'package:z/providers/storage_provider.dart';
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
      }
    } catch (e) {
      log('Error picking media: $e');
    }
  }

  String _getConversationId() {
    final ids = [widget.currentUserId, widget.otherUserId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _sendMessage() async {
    if (_selectedFiles.isNotEmpty) {
      final files = [..._selectedFiles];
      setState(() => _selectedFiles = []);
      final uploadNotifier = ref.read(uploadNotifierProvider.notifier);
      final referenceId = _getConversationId();
      uploadNotifier.uploadFiles(
        files: files,
        type: UploadType.document,
        referenceId: referenceId,
        onComplete: (urls) {
          _sendMessageText(referenceId: referenceId, mediaUrls: urls);
        },
      );
    } else {
      await _sendMessageText();
    }
  }

  Future<void> _sendMessageText({
    String? referenceId,
    List<String>? mediaUrls,
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) return;

    try {
      final messageService = ref.read(messageServiceProvider);

      if (text.isNotEmpty) {
        await messageService.sendMessage(
          referenceId: referenceId,
          senderId: widget.currentUserId,
          receiverId: widget.otherUserId,
          text: text,
          mediaUrls: mediaUrls,
        );
        Helpers.createNotification(
          userId: widget.otherUserId,
          fromUserId: widget.currentUserId,
          type: NotificationType.message,
        );
      }

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
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate dynamic extra offset — only if content is taller than screen
    final extraOffset = maxScroll > screenHeight ? screenHeight * 0.2 : 0.0;

    // Prevent overscrolling beyond available content
    final target = (maxScroll + extraOffset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.jumpTo(target);
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
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.insert_drive_file, size: 40),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      messagesProvider((widget.currentUserId, widget.otherUserId)),
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
                  if (_scrollController.hasClients &&
                      _scrollController.offset <
                          _scrollController.position.maxScrollExtent - 100) {
                    // Only scroll automatically if not already near the bottom
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
                log("Error $error");
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
