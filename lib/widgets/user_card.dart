import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/widgets/profile_picture.dart';
import '../models/user_model.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';

class UserCard extends ConsumerWidget {
  final UserModel user;
  final bool showFollowButton;

  const UserCard({super.key, required this.user, this.showFollowButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      return SizedBox.shrink();
    }
    final isOwnProfile = currentUser.uid == user.id;

    void onTap() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen(userId: user.id)),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ProfilePicture(pfp: user.profilePictureUrl, name: user.displayName),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.isVerified) ...[
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
                    '@${user.username}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (user.bio != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Follow button
            if (!isOwnProfile && showFollowButton)
              SizedBox(
                width: 96,
                child: _followButton(currentUser.uid, user.id, ref),
              ),
          ],
        ),
      ),
    );
  }

  Widget _followButton(String currentUserId, String userId, WidgetRef ref) {
    final profileService = ref.read(profileServiceProvider);

    return FutureBuilder<bool>(
      future: profileService.isFollowing(currentUserId, userId),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                isLoading
                    ? null
                    : () async {
                      if (isFollowing) {
                        await profileService.unfollowUser(
                          currentUserId,
                          userId,
                        );
                      } else {
                        await profileService.followUser(currentUserId, userId);
                      }

                      // Trigger rebuild after following/unfollowing
                      (context as Element).markNeedsBuild();
                    },
            child:
                isLoading
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(isFollowing ? 'Following' : 'Follow'),
          ),
        );
      },
    );
  }
}
