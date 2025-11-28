import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/providers/message_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/common/profile_picture.dart';
import '../../providers/auth_provider.dart';
import 'package:z/screens/home/widgets/following_tab.dart';
import 'package:z/screens/home/widgets/for_you_tab.dart';
import 'package:z/screens/home/widgets/home_drawer.dart';
import 'package:z/screens/home/widgets/icon_with_badge.dart';

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
      drawer: HomeDrawer(currentUser: currentUser, onLogout: _logout),
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
              children: [
                const ForYouTab(),
                FollowingTab(userId: currentUser.uid),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
