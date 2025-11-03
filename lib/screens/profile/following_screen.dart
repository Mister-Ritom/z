import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/user_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../profile/profile_screen.dart';

class FollowingScreen extends ConsumerWidget {
  final String userId;

  const FollowingScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(userFollowingProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: followingAsync.when(
        data: (followingIds) {
          if (followingIds.isEmpty) {
            return const Center(child: Text('Not following anyone yet'));
          }

          return ListView.builder(
            itemCount: followingIds.length,
            itemBuilder: (context, index) {
              final followingId = followingIds[index];
              final userAsync = ref.watch(userProfileProvider(followingId));

              return userAsync.when(
                data: (user) {
                  if (user == null) {
                    return const SizedBox.shrink();
                  }
                  return UserCard(
                    user: user,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(userId: user.id),
                        ),
                      );
                    },
                  );
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
