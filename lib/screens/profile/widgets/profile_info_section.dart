import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/utils/helpers.dart';

class ProfileInfoSection extends ConsumerWidget {
  final UserModel user;
  final bool isOwnProfile;
  final UserModel? currentUser;
  final VoidCallback onEditProfile;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  final VoidCallback? onMessageTap;

  const ProfileInfoSection({
    super.key,
    required this.user,
    required this.isOwnProfile,
    required this.currentUser,
    required this.onEditProfile,
    required this.onFollowersTap,
    required this.onFollowingTap,
    this.onMessageTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        user.profilePictureUrl != null
                            ? CachedNetworkImageProvider(
                              user.profilePictureUrl!,
                            )
                            : null,
                    child:
                        user.profilePictureUrl == null
                            ? Text(
                              user.displayName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 40),
                            )
                            : null,
                  ),
                  if (isOwnProfile)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: onEditProfile,
                      ),
                    ),
                ],
              ),
              if (!isOwnProfile && currentUser != null)
                SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FollowButton(
                        currentUserId: currentUser!.id,
                        userId: user.id,
                      ),
                      const SizedBox(height: 12),
                      if (onMessageTap != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onMessageTap,
                            child: const Text('Message'),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.verified,
                  size: 24,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.username}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (user.bio != null) ...[
            const SizedBox(height: 12),
            Text(user.bio!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(
                label: 'Following',
                count: user.followingCount,
                onTap: onFollowingTap,
              ),
              const SizedBox(width: 24),
              _StatTile(
                label: 'Followers',
                count: user.followersCount,
                onTap: onFollowersTap,
              ),
              const SizedBox(width: 24),
              _StatTile(label: 'Zaps', count: user.zapsCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String currentUserId;
  final String userId;

  const _FollowButton({required this.currentUserId, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      (context as Element).markNeedsBuild();
                    },
            child:
                isLoading
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(isFollowing ? 'Unfollow' : 'Follow'),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _StatTile({required this.label, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Helpers.formatNumber(count),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
