import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/providers/message_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/providers/theme_provider.dart';
import 'package:z/utils/helpers.dart';
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
    final uploads = ref.watch(uploadNotifierProvider);
    final tweetUploads =
        uploads.where((task) => task.type == UploadType.tweet).toList();
    final totalProgress =
        tweetUploads.isEmpty
            ? null
            : tweetUploads.map((e) => e.progress).reduce((a, b) => a + b) /
                uploads.length;

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
              currentAccountPicture: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile/${currentUser.id}');
                },
                child: CircleAvatar(
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
            ),

            // Profile
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/${currentUser.id}');
              },
            ),

            // Bookmarks
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Bookmarks'),
              onTap: () {
                Navigator.pop(context);
                context.push('/bookmarks');
              },
            ),

            // Settings
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            const Divider(),

            // Feedback
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Feedback'),
              onTap: () {
                Navigator.pop(context);
                context.push('/feedback');
              },
            ),

            // Terms
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Terms of Service'),
              onTap: () {
                Navigator.pop(context);
                context.push('/terms');
              },
            ),

            // Privacy Policy
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(context);
                context.push('/privacy');
              },
            ),

            const Divider(),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout(ref);
              },
            ),
            Divider(),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Change theme',
                  icon: Icon(switch (ref.watch(themeProvider)) {
                    AppTheme.light => Icons.light_mode_outlined,
                    AppTheme.dark => Icons.dark_mode_outlined,
                    AppTheme.system => Icons.brightness_auto_outlined,
                  }),
                  onPressed: () {
                    ref.read(themeProvider.notifier).setTheme(switch (ref.read(
                      themeProvider,
                    )) {
                      AppTheme.light => AppTheme.dark,
                      AppTheme.dark => AppTheme.system,
                      AppTheme.system => AppTheme.light,
                    });
                  },
                ),
                Text(switch (ref.watch(themeProvider)) {
                  AppTheme.light => "Light",
                  AppTheme.dark => "Dark",
                  AppTheme.system => "System",
                }),
              ],
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
        title: Image.asset(
          Helpers.getIconAsset(brightness: Theme.brightnessOf(context)),
          width: 48,
          height: 48,
        ),
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
      body: Column(
        children: [
          if (totalProgress != null)
            LinearProgressIndicator(
              value: totalProgress,
              backgroundColor: Colors.grey.shade800,
              color: Theme.of(context).colorScheme.primary,
              minHeight: 4,
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_ForYouTab(), _FollowingTab(userId: currentUser.id)],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForYouTab extends ConsumerStatefulWidget {
  const _ForYouTab({Key? key}) : super(key: key);

  @override
  ConsumerState<_ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends ConsumerState<_ForYouTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(forYouFeedProvider.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrollPos = _scrollController.position;
    if (scrollPos.pixels >= scrollPos.maxScrollExtent - 200) {
      ref.read(forYouFeedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(forYouFeedProvider.notifier).loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final tweets = ref.watch(forYouFeedProvider);

    if (tweets.isEmpty) {
      return const Center(child: Text('No tweets yet'));
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
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
                          builder: (context) => ProfileScreen(userId: user.id),
                        ),
                      );
                    }
                  },
                ),
            loading: () => const TweetCardShimmer(),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
      ),
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
