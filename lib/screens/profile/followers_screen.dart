import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_provider.dart';
import 'package:z/widgets/common/user_card.dart';
import 'package:z/widgets/common/loading_shimmer.dart';

class FollowersScreen extends ConsumerWidget {
  final String userId;

  const FollowersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersAsync = ref.watch(userFollowersProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: followersAsync.when(
        data: (followerIds) {
          if (followerIds.isEmpty) {
            return const Center(child: Text('No followers yet'));
          }

          return ListView.builder(
            itemCount: followerIds.length,
            itemBuilder: (context, index) {
              final followerId = followerIds[index];
              final userAsync = ref.watch(userProfileProvider(followerId));

              return userAsync.when(
                data: (user) {
                  if (user == null) {
                    return const SizedBox.shrink();
                  }
                  return UserCard(user: user);
                },
                loading:
                    () => const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          LoadingShimmer(
                            width: 48,
                            height: 48,
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LoadingShimmer(width: 150, height: 16),
                                SizedBox(height: 4),
                                LoadingShimmer(width: 100, height: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          );
        },
        loading:
            () => ListView.builder(
              itemCount: 10,
              itemBuilder:
                  (context, index) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        LoadingShimmer(
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LoadingShimmer(width: 150, height: 16),
                              SizedBox(height: 4),
                              LoadingShimmer(width: 100, height: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
        error: (error, stack) {
          log("Error: $error", stackTrace: stack);
          return Center(child: Text('Error: $error'));
        },
      ),
    );
  }
}
