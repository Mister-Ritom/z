import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/zap_provider.dart';

class CommentSheet extends ConsumerStatefulWidget {
  final String zapId;
  final String currentUserId;

  const CommentSheet({
    super.key,
    required this.zapId,
    required this.currentUserId,
  });

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final zapService = ref.read(zapServiceProvider(true));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: zapService.getComments(widget.zapId),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? [];
                    return ListView.builder(
                      controller: controller,
                      itemCount: comments.length,
                      itemBuilder: (_, index) {
                        final data = comments[index];
                        final text = data['text'] ?? '';
                        final userId = data['user_id'] ?? '';
                        return ListTile(
                          title: Text(text),
                          subtitle: Text(userId),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      await zapService.addComment(
                        postId: widget.zapId,
                        userId: widget.currentUserId,
                        text: text,
                      );
                      setState(() {}); // Refresh to see new comment
                      _controller.clear();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
