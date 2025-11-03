import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/providers/message_provider.dart';
import 'package:z/providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tweet_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/tweet_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/tweet_composer.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Future<void> _logout(WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final notificationsAsync = ref.watch(
      unreadNotificationsCountProvider(currentUser.id),
    );
    final unreadMessagesAsync = ref.watch(
      unreadMessageCountProvider(currentUser.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          Row(
            children: [
              notificationsAsync.when(
                data:
                    (count) => IconWithBadge(
                      icon: Icons.notifications_outlined,
                      count: count,
                      onPressed: () => context.push('/notifications'),
                    ),
                loading: () => const SizedBox.shrink(),
                error: (e, st) {
                  log(
                    "Error getting notification count",
                    error: e,
                    stackTrace: st,
                  );
                  return IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/notifications'),
                  );
                },
              ),
              unreadMessagesAsync.when(
                data:
                    (count) => IconWithBadge(
                      icon: Icons.mail_outline,
                      count: count,
                      onPressed: () => context.push('/messages'),
                    ),
                loading: () => const SizedBox.shrink(),
                error: (e, st) {
                  log(
                    "Error getting unread messages count",
                    error: e,
                    stackTrace: st,
                  );
                  return IconButton(
                    icon: const Icon(Icons.mail_outline),
                    onPressed: () => context.push('/messages'),
                  );
                },
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage:
                  currentUser.profilePictureUrl != null
                      ? NetworkImage(currentUser.profilePictureUrl!)
                      : null,
              child:
                  currentUser.profilePictureUrl == null
                      ? Text(
                        currentUser.displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      )
                      : null,
            ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  context.push('/profile/${currentUser.id}');
                  break;
                case 'logout':
                  _logout(ref);
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: const Row(
                      children: [
                        Icon(Icons.person_outline),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
        bottom: TabBar(
          dividerColor: Colors.transparent,
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: 'For You'), Tab(text: 'Following')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_ForYouTab(), _FollowingTab(userId: currentUser.id)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TweetComposer()),
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _ForYouTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tweetsAsync = ref.watch(forYouFeedProvider);

    return tweetsAsync.when(
      data: (tweets) {
        if (tweets.isEmpty) {
          return const Center(child: Text('No tweets yet'));
        }

        return ListView.builder(
          itemCount: tweets.length,
          itemBuilder: (context, index) {
            final tweet = tweets[index];

            final userAsync = ref.watch(userProfileProvider(tweet.userId));

            return userAsync.when(
              data:
                  (user) => TweetCard(
                    tweet: tweet,
                    user: user,
                    onTap: () {
                      context.push('/tweet/${tweet.id}');
                    },
                    onUserTap: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProfileScreen(userId: user.id),
                          ),
                        );
                      }
                    },
                  ),
              loading: () => const TweetCardShimmer(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
        );
      },
      loading:
          () => ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => const TweetCardShimmer(),
          ),
      error: (error, stack) {
        log("Error: $error");
        return Center(child: Text('Error: $error'));
      },
    );
  }
}

class _FollowingTab extends ConsumerWidget {
  final String userId;

  const _FollowingTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tweetsAsync = ref.watch(followingFeedProvider(userId));

    return tweetsAsync.when(
      data: (tweets) {
        if (tweets.isEmpty) {
          return const Center(
            child: Text('Follow users to see their tweets here'),
          );
        }

        return ListView.builder(
          itemCount: tweets.length,
          itemBuilder: (context, index) {
            final tweet = tweets[index];
            final userAsync = ref.watch(userProfileProvider(tweet.userId));

            return userAsync.when(
              data:
                  (user) => TweetCard(
                    tweet: tweet,
                    user: user,
                    onTap: () {
                      context.push('/tweet/${tweet.id}');
                    },
                    onUserTap: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProfileScreen(userId: user.id),
                          ),
                        );
                      }
                    },
                  ),
              loading: () => const TweetCardShimmer(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
        );
      },
      loading:
          () => ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => const TweetCardShimmer(),
          ),
      error: (error, stack) {
        log("Error: $error");
        return Center(child: Text('Error: $error'));
      },
    );
  }
}

class IconWithBadge extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int count;
  final Color badgeColor;
  final Color iconColor;

  const IconWithBadge({
    super.key,
    required this.icon,
    required this.onPressed,
    this.count = 0,
    this.badgeColor = Colors.red,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon, color: iconColor), onPressed: onPressed),
        if (count > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
