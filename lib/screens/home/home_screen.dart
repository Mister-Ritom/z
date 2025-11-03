import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/providers/message_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tweet_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/tweet_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _logout(WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (mounted) context.go('/login');
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

  /// 🔹 Helper function for mail icon with badge
  Widget _buildIconWithBadge({
    required IconData icon,
    required int count,
    required VoidCallback onPressed,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon, color: Colors.white), onPressed: onPressed),
        if (count > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final unreadMessagesAsync = ref.watch(
      unreadMessageCountProvider(currentUser.id),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color:
                    currentUser.coverPhotoUrl == null
                        ? Theme.of(context).colorScheme.surface
                        : null,
                image:
                    currentUser.coverPhotoUrl != null
                        ? DecorationImage(
                          image: NetworkImage(currentUser.coverPhotoUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.5),
                            BlendMode.darken,
                          ),
                        )
                        : null,
              ),

              accountName: Text(currentUser.displayName),
              accountEmail: Text(currentUser.email),
              currentAccountPicture: CircleAvatar(
                backgroundImage:
                    currentUser.profilePictureUrl != null
                        ? CachedNetworkImageProvider(
                          currentUser.profilePictureUrl!,
                        )
                        : null,
                child:
                    currentUser.profilePictureUrl == null
                        ? Text(currentUser.displayName[0].toUpperCase())
                        : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/${currentUser.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout(ref);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundImage:
                  currentUser.profilePictureUrl != null
                      ? NetworkImage(currentUser.profilePictureUrl!)
                      : null,
              child:
                  currentUser.profilePictureUrl == null
                      ? Text(
                        currentUser.displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 14),
                      )
                      : null,
            ),
          ),
        ),
        title: const Text('Home'),
        actions: [
          unreadMessagesAsync.when(
            data:
                (count) => _buildIconWithBadge(
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
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
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
    );
  }
}

class _ForYouTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tweetsAsync = ref.watch(forYouFeedProvider);
    return tweetsAsync.when(
      data: (tweets) {
        if (tweets.isEmpty) return const Center(child: Text('No tweets yet'));
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
                    onTap: () => context.push('/tweet/${tweet.id}'),
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
      error: (e, st) {
        log("Error: $e");
        return Center(child: Text('Error: $e'));
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
                    onTap: () => context.push('/tweet/${tweet.id}'),
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
      error: (e, st) {
        log("Error: $e");
        return Center(child: Text('Error: $e'));
      },
    );
  }
}
