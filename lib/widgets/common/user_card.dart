import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/screens/profile/profile_screen.dart';
import 'package:z/widgets/common/profile_picture.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/auth_provider.dart';

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
    return _FollowButtonWidget(currentUserId: currentUserId, userId: userId);
  }
}

class _FollowButtonWidget extends ConsumerStatefulWidget {
  final String currentUserId;
  final String userId;

  const _FollowButtonWidget({
    required this.currentUserId,
    required this.userId,
  });

  @override
  ConsumerState<_FollowButtonWidget> createState() =>
      _FollowButtonWidgetState();
}

class _FollowButtonWidgetState extends ConsumerState<_FollowButtonWidget> {
  bool? _isFollowing;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowingStatus();
  }

  Future<void> _loadFollowingStatus() async {
    final profileService = ref.read(profileServiceProvider);
    final isFollowing = await profileService.isFollowing(
      widget.currentUserId,
      widget.userId,
    );
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
            _isLoading
                ? null
                : () async {
                  setState(() {
                    _isLoading = true;
                  });

                  final profileService = ref.read(profileServiceProvider);
                  if (_isFollowing == true) {
                    await profileService.unfollowUser(
                      widget.currentUserId,
                      widget.userId,
                    );
                  } else {
                    await profileService.followUser(
                      widget.currentUserId,
                      widget.userId,
                    );
                  }

                  if (mounted) {
                    setState(() {
                      _isFollowing = !(_isFollowing ?? false);
                      _isLoading = false;
                    });
                  }
                },
        child:
            _isLoading
                ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(_isFollowing == true ? 'Following' : 'Follow'),
      ),
    );
  }
}
