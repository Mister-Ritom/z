import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:z/widgets/media/media_carousel.dart';
import 'package:z/models/message_model.dart';
import 'package:z/providers/message_provider.dart';
import 'package:z/widgets/moderation/block_confirmation_dialog.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    if (_isDeleting || !widget.isMe) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BlockConfirmationDialog(
        title: 'Delete Message',
        message: 'Are you sure you want to delete this message?',
        confirmText: 'Delete',
        onConfirm: () {},
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final messageService = ref.read(messageServiceProvider);

    try {
      await messageService.deleteMessage(
        messageId: widget.message.id,
        userId: widget.message.senderId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        widget.isMe
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.surfaceContainerHighest;

    final textColor =
        widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: widget.isMe && !_isDeleting ? _handleDelete : null,
        child: Stack(
          children: [
            Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    widget.isMe ? const Radius.circular(16) : const Radius.circular(0),
                bottomRight:
                    widget.isMe ? const Radius.circular(0) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),

                if (widget.message.mediaUrls != null && widget.message.mediaUrls!.isNotEmpty)
                  MediaCarousel(mediaUrls: widget.message.mediaUrls!, maxHeight: 450),

                const SizedBox(height: 4),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment:
                      widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Text(
                      timeago.format(widget.message.createdAt),
                      style: TextStyle(
                        color: widget.isMe ? Colors.white70 : Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                    if (widget.isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        widget.message.isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 16,
                        color:
                            widget.message.isRead
                                ? Colors.lightBlueAccent
                                : (widget.isMe ? Colors.white70 : Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          if (widget.message.isPending)
            Positioned(
              bottom: 6,
              right: widget.isMe ? 14 : null,
              left: widget.isMe ? null : 14,
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
          if (_isDeleting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
