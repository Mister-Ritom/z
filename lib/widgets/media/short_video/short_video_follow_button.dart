import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/profile_provider.dart';

class ShortVideoFollowButton extends ConsumerWidget {
  final String currentUserId;
  final String userId;

  const ShortVideoFollowButton({
    super.key,
    required this.currentUserId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileService = ref.read(profileServiceProvider);

    return FutureBuilder<bool>(
      future: profileService.isFollowing(currentUserId, userId),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        if (isFollowing) return const SizedBox.shrink();

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed:
                isLoading
                    ? null
                    : () async {
                      await profileService.followUser(currentUserId, userId);
                      (context as Element).markNeedsBuild();
                    },
            child:
                isLoading
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(
                      'Follow',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
          ),
        );
      },
    );
  }
}
