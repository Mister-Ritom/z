import 'dart:developer';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/info/zap/zap_detail_screen.dart';
import 'package:z/providers/message_provider.dart';
import 'package:z/providers/settings_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/services/ad_manager.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/feed_with_ads.dart';
import 'package:z/widgets/profile_picture.dart';
import '../../providers/auth_provider.dart';
import '../../providers/zap_provider.dart';
import '../../widgets/zap_card.dart';
import '../../widgets/loading_shimmer.dart';

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
        IconButton(icon: Icon(icon), onPressed: onPressed),
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
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final unreadMessagesAsync = ref.watch(
      unreadMessageCountProvider(currentUser.uid),
    );
    final uploads = ref.watch(uploadNotifierProvider);
    final zapUploads =
        uploads
            .where(
              (task) =>
                  task.type == UploadType.zap || task.type == UploadType.shorts,
            )
            .toList();
    final totalProgress =
        zapUploads.isEmpty
            ? null
            : zapUploads.map((e) => e.progress).reduce((a, b) => a + b) /
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
                    (ref.watch(
                              currentUserModelProvider,
                            )).valueOrNull?.coverPhotoUrl ==
                            null
                        ? Theme.of(context).colorScheme.surface
                        : null,
                image:
                    (ref.watch(
                              currentUserModelProvider,
                            )).valueOrNull?.coverPhotoUrl !=
                            null
                        ? DecorationImage(
                          image: CachedNetworkImageProvider(
                            (ref.watch(
                              currentUserModelProvider,
                            )).valueOrNull!.coverPhotoUrl!,
                          ),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.5),
                            BlendMode.darken,
                          ),
                        )
                        : null,
              ),
              accountName: Text(
                currentUser.displayName ?? "No Name",
                style: TextTheme.of(context).bodyMedium,
              ),
              accountEmail: Text(
                currentUser.email ?? "No Email",
                style: TextTheme.of(context).bodyMedium,
              ),
              currentAccountPicture: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile/${currentUser.uid}');
                },
                child: ProfilePicture(
                  pfp: currentUser.photoURL,
                  name: currentUser.displayName,
                ),
              ),
            ),

            // Profile
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/${currentUser.uid}');
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
                Navigator.pop(context); // closes the drawer
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed:
                                () => Navigator.pop(context), // dismiss dialog
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // dismiss dialog
                              _logout(ref); // perform logout
                            },
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                );
              },
            ),
            Divider(),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(switch (ref.watch(settingsProvider).theme) {
                AppTheme.light => Icons.light_mode_outlined,
                AppTheme.dark => Icons.dark_mode_outlined,
                AppTheme.system => Icons.brightness_auto_outlined,
              }),
              title: Text(switch (ref.watch(settingsProvider).theme) {
                AppTheme.light => "Light",
                AppTheme.dark => "Dark",
                AppTheme.system => "System",
              }),
              onTap: () {
                final settings = ref.read(settingsProvider);
                final notifier = ref.read(settingsProvider.notifier);

                final nextTheme = switch (settings.theme) {
                  AppTheme.light => AppTheme.dark,
                  AppTheme.dark => AppTheme.system,
                  AppTheme.system => AppTheme.light,
                };

                notifier.setTheme(nextTheme);
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
            child: ProfilePicture(
              pfp: currentUser.photoURL,
              name: currentUser.displayName,
            ),
          ),
        ),
        title: Image.asset(
          Helpers.getIconAsset(brightness: Theme.brightnessOf(context)),
          width: 48,
          height: 48,
        ),
        centerTitle: true,
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
              children: [_ForYouTab(), _FollowingTab(userId: currentUser.uid)],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForYouTab extends ConsumerStatefulWidget {
  const _ForYouTab();

  @override
  ConsumerState<_ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends ConsumerState<_ForYouTab> {
  final ScrollController _scrollController = ScrollController();
  final AdManager _adManager = AdManager();
  get forYouFeed => forYouFeedProvider(false);

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) async {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
    });
    Future.microtask(() {
      ref.read(forYouFeed.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrollPos = _scrollController.position;
    if (scrollPos.pixels >= scrollPos.maxScrollExtent - 200) {
      ref.read(forYouFeed.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(forYouFeed.notifier).refreshFeed();
  }

  @override
  Widget build(BuildContext context) {
    final zaps = ref.watch(forYouFeed);

    if (zaps.isEmpty) {
      return const Center(child: Text('No zaps yet'));
    }

    // Inject ads into zap feed
    final feedItems = _adManager.injectAdsIntoZapBatch(zaps);
    final items = createFeedItems(feedItems);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text("You reached the end")),
            ); // space for bottom nav
          }
          // CRITICAL: Add unique key to prevent widget rebuild issues during scroll
          final item = items[index];
          final key =
              item is ZapFeedItem
                  ? ValueKey('zap_${item.zap.id}')
                  : item is AdFeedItem
                  ? ValueKey('ad_${item.placement.index}')
                  : ValueKey('item_$index');

          return FeedItemWidget(
            key: key,
            item: item,
            onZapTap: () {
              if (item is ZapFeedItem) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ZapDetailScreen(zapId: item.zap.id),
                  ),
                );
              }
            },
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
    final zapsAsync = ref.watch(followingFeedProvider(userId));
    return zapsAsync.when(
      data: (zaps) {
        if (zaps.isEmpty) {
          return const Center(
            child: Text('Follow users to see their zaps here'),
          );
        }
        return ListView.builder(
          itemCount: zaps.length + 1,
          itemBuilder: (context, index) {
            if (index == zaps.length) {
              return const SizedBox(
                height: 160,
                child: Center(child: Text("You reached the end")),
              ); // space for bottom nav
            }
            final zap = zaps[index];
            return ZapCard(zap: zap);
          },
        );
      },
      loading:
          () => ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => const ZapCardShimmer(),
          ),
      error: (e, st) {
        log("Error: $e");
        return Center(child: Text('Error: $e'));
      },
    );
  }
}
