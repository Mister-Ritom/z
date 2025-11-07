import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';

class UserCard extends ConsumerWidget {
  final UserModel user;
  final VoidCallback? onTap;
  final bool showFollowButton;

  const UserCard({
    super.key,
    required this.user,
    this.onTap,
    this.showFollowButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      return SizedBox.shrink();
    }
    final isOwnProfile = currentUser.uid == user.id;

    final isFollowingAsync = ref.watch(
      isFollowingProvider({
        'currentUserId': currentUser.uid,
        'targetUserId': user.id,
      }),
    );

    final isFollowing = isFollowingAsync.valueOrNull ?? false;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  user.profilePictureUrl != null
                      ? CachedNetworkImageProvider(user.profilePictureUrl!)
                      : null,
              child:
                  user.profilePictureUrl == null
                      ? Text(
                        user.displayName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                      : null,
            ),
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
            if (showFollowButton && !isOwnProfile)
              ElevatedButton(
                onPressed: () async {
                  final profileService = ref.read(profileServiceProvider);
                  if (isFollowing) {
                    await profileService.unfollowUser(currentUser.uid, user.id);
                  } else {
                    await profileService.followUser(currentUser.uid, user.id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFollowing
                          ? Colors.transparent
                          : Theme.of(context).colorScheme.secondary,
                  foregroundColor:
                      isFollowing
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.inverseSurface,
                  side:
                      isFollowing
                          ? BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          )
                          : null,
                ),
                child: Text(isFollowing ? 'Following' : 'Follow'),
              ),
          ],
        ),
      ),
    );
  }
}
