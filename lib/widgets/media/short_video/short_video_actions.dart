import 'package:flutter/material.dart';

class ShortVideoActions extends StatelessWidget {
  final bool isLiked;
  final int? commentsCount;
  final int? sharesCount;
  final bool isBookmarked;
  final bool isBookmarking;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const ShortVideoActions({
    super.key,
    required this.isLiked,
    required this.commentsCount,
    required this.sharesCount,
    required this.isBookmarked,
    required this.isBookmarking,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onBookmark,
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
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color:
              isBookmarked
                  ? Theme.of(context).colorScheme.inverseSurface
                  : Colors.grey,
          isLoading: isBookmarking,
          onTap: onBookmark,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.count,
    this.color = Colors.white,
    this.isLoading = false,
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
