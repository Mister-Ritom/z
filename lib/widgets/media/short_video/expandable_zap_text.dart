import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class ExpandableZapText extends StatefulWidget {
  final String text;
  final DateTime createdAt;

  const ExpandableZapText({
    super.key,
    required this.text,
    required this.createdAt,
  });

  @override
  State<ExpandableZapText> createState() => _ExpandableZapTextState();
}

class _ExpandableZapTextState extends State<ExpandableZapText> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final timeAgoText = timeago.format(widget.createdAt);

    return GestureDetector(
      onTap: () => setState(() => expanded = !expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: expanded ? null : 1,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            timeAgoText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
