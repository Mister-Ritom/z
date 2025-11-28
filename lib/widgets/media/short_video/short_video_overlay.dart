import 'package:flutter/material.dart';
import 'package:z/models/user_model.dart';
import 'package:z/widgets/common/profile_picture.dart';
import 'package:z/widgets/media/short_video/expandable_zap_text.dart';
import 'package:z/widgets/media/short_video/short_video_follow_button.dart';

class ShortVideoOverlay extends StatelessWidget {
  final UserModel? user;
  final String currentUserId;
  final String zapUserId;
  final String zapText;
  final DateTime createdAt;
  final VoidCallback onProfileTap;

  const ShortVideoOverlay({
    super.key,
    required this.user,
    required this.currentUserId,
    required this.zapUserId,
    required this.zapText,
    required this.createdAt,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onProfileTap,
              child: ProfilePicture(
                pfp: user?.profilePictureUrl,
                name: user?.displayName,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user?.displayName ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    if (user?.isVerified ?? false) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 18,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ],
                ),
                Text(
                  '@${user?.username ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 8),
            if (user != null && currentUserId != user!.id)
              SizedBox(
                width: 90,
                child: ShortVideoFollowButton(
                  currentUserId: currentUserId,
                  userId: user!.id,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ExpandableZapText(text: zapText, createdAt: createdAt),
      ],
    );
  }
}
