import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/user_model.dart';
import 'package:z/screens/messages/chat_screen.dart';
import 'package:z/screens/profile/widgets/profile_app_bar.dart';
import 'package:z/screens/profile/widgets/profile_info_section.dart';
import 'package:z/screens/profile/widgets/profile_tab_header.dart';
import 'package:z/screens/profile/widgets/tabs/likes_tab.dart';
import 'package:z/screens/profile/widgets/tabs/media_tab.dart';
import 'package:z/screens/profile/widgets/tabs/replies_tab.dart';
import 'package:z/screens/profile/widgets/tabs/zaps_tab.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/moderation_provider.dart';
import '../../models/report_model.dart';
import '../../widgets/moderation/block_confirmation_dialog.dart';
import '../../widgets/moderation/report_dialog.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import 'following_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    final isOwnProfile = currentUser?.id == widget.userId;
    final userAsync = ref.watch(userProfileProvider(widget.userId));

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // App bar with cover photo
                ProfileAppBar(
                  user: user,
                  isOwnProfile: isOwnProfile,
                  onEditProfile: () => _openEditProfile(user),
                  onReportUser: () => _showReportDialog(context),
                  onBlockUser: () => _showBlockDialog(context),
                ),
                // Profile info
                SliverToBoxAdapter(
                  child: ProfileInfoSection(
                    user: user,
                    isOwnProfile: isOwnProfile,
                    currentUser: currentUser,
                    onEditProfile: () => _openEditProfile(user),
                    onFollowersTap: () => _openFollowers(),
                    onFollowingTap: () => _openFollowing(),
                    onMessageTap:
                        currentUser == null
                            ? null
                            : () => _openChat(currentUser.id, user),
                  ),
                ),
                // Tabs
                SliverPersistentHeader(
                  pinned: true,
                  delegate: ProfileTabHeader(
                    tabBar: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Zaps'),
                        Tab(text: 'Replies'),
                        Tab(text: 'Media'),
                        Tab(text: 'Likes'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                ZapsTab(userId: widget.userId, profileUser: user),
                RepliesTab(userId: widget.userId),
                MediaTab(userId: widget.userId),
                LikesTab(userId: widget.userId),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          log("Error: $error");
          return Center(child: Text('Error: $error'));
        },
      ),
    );
  }

  void _openEditProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)),
    );
  }

  void _openFollowers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowersScreen(userId: widget.userId),
      ),
    );
  }

  void _openFollowing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowingScreen(userId: widget.userId),
      ),
    );
  }

  void _openChat(String currentUserId, UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: user.id)),
    );
  }

  void _showReportDialog(BuildContext context) {
    final currentUser = ref.read(currentUserModelProvider).valueOrNull;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder:
          (ctx) => ReportDialog(
            reportType: ReportType.user,
            userId: widget.userId,
            reporterId: currentUser.id,
          ),
    );
  }

  void _showBlockDialog(BuildContext context) async {
    final currentUser = ref.read(currentUserModelProvider).valueOrNull;
    if (currentUser == null) return;

    final userAsync = ref.read(userProfileProvider(widget.userId));
    final user = userAsync.valueOrNull;
    final username = user?.username ?? widget.userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => BlockConfirmationDialog(
            title: 'Block User',
            message:
                'Block @$username? You won\'t see their posts in your feed.',
            onConfirm: () {},
          ),
    );

    if (confirmed != true) return;

    final blockService = ref.read(blockServiceProvider);

    try {
      await blockService.blockUserForContent(
        blockerId: currentUser.id,
        blockedUserId: widget.userId,
      );
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked successfully')),
        );
        Navigator.of(context).pop(); // Go back after blocking
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to block user: $e')));
      }
    }
  }
}
