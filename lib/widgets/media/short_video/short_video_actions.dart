import 'package:flutter/material.dart';

class ShortVideoActions extends StatelessWidget {
  final bool isLiked;
  final int? commentsCount;
  final int? sharesCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMoreOptions;

  const ShortVideoActions({
    super.key,
    required this.isLiked,
    required this.commentsCount,
    required this.sharesCount,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          color: isLiked ? Colors.pink : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.comment_outlined,
          count: commentsCount,
          onTap: onComment,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.share_outlined,
          count: sharesCount,
          onTap: onShare,
        ),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.more_vert,
          color: Colors.white,
          onTap: onMoreOptions,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color color;
  final bool isLoading = false;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.count,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: isLoading ? null : onTap,
          child:
              isLoading
                  ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                  : Icon(icon, color: color, size: 28),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(height: 4),
          Text(count.toString(), style: TextStyle(color: color, fontSize: 12)),
        ],
      ],
    );
  }
}
