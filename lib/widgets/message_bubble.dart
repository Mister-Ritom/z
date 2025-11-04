import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/video_player_widget.dart';
import '../models/message_model.dart';
import 'photo_view_screen.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isMe
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.surfaceContainerHighest;

    final textColor =
        isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
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
                isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(16),
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
            // Text
            if (message.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                ),
              ),

            // Image Grid
            if (message.imageUrls != null && message.imageUrls!.isNotEmpty)
              _buildImageGrid(context, message.imageUrls!),

            // Video
            if (message.videoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoPlayerWidget(
                    isFile: false,
                    url: message.videoUrl!,
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // Time + Read Status
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  timeago.format(message.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 16,
                    color:
                        message.isRead
                            ? Colors.lightBlueAccent
                            : (isMe ? Colors.white70 : Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> urls) {
    final displayCount = urls.length > 4 ? 4 : urls.length;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GridView.builder(
        itemCount: displayCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (context, index) {
          final imageUrl = urls[index];
          final isLastVisible = index == 3 && urls.length > 4;
          final remaining = urls.length - 4;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => PhotoViewScreen(images: urls, initialIndex: index),
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage.network(imageUrl, fit: BoxFit.cover),
                ),
                if (isLastVisible)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '+$remaining',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
