import 'dart:async';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:z/screens/creation/creation_screen.dart';
import 'package:z/screens/home/home_screen.dart';
import 'package:z/screens/search/search_screen.dart';
import 'package:z/screens/shorts/shorts_screen.dart';
import 'package:z/screens/stories/stories_screen.dart';
import 'package:z/screens/notifications/notifications_screen.dart';
import 'package:z/providers/notification_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/utils/logger.dart';

extension ColorX on Color {
  Color withOpacityAlpha(double opacity) {
    return withValues(alpha: opacity);
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  final currentIndexProvider = StateProvider((ref) => 0);
  final _pageController = PageController();

  List<Widget> get _pages => [
    const HomeScreen(),
    const SearchScreen(),
    const ShortsScreen(),
    const StoriesScreen(),
    const NotificationsScreen(),
  ];

  void _markNotificationsRead(String userId) {
    try {
      unawaited(markAllNotificationsAsRead(userId));
      AppLogger.info(
        "Main Nav",
        '✅ Marked notifications as read for user $userId',
      );
    } catch (e, st) {
      AppLogger.error(
        "Main Nav",
        " Error setting notifications to read",
        error: e,
        stackTrace: st,
      );
    }
  }

  void _onItemTapped(int index) {
    final notifier = ref.read(currentIndexProvider.notifier);
    final currentIndex = notifier.state;
    if (index == currentIndex) return;
    _pageController.jumpToPage(index);
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final page = _pages[index];
    if (page is NotificationsScreen && currentUser != null) {
      _markNotificationsRead(currentUser.uid);
    }
    notifier.state = index;
  }

  void _onFabTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreationScreen()),
    );
  }

  IconData _getPageIcon(Widget page) {
    return switch (page) {
      HomeScreen() => LucideIcons.zap,
      SearchScreen() => LucideIcons.search,
      ShortsScreen() => LucideIcons.play,
      StoriesScreen() => LucideIcons.circleDashed,
      NotificationsScreen() => LucideIcons.bell,
      _ => Icons.help_outline,
    };
  }

  String _getPageLabel(Widget page) {
    return switch (page) {
      HomeScreen() => 'Zap',
      SearchScreen() => 'Search',
      ShortsScreen() => 'Shorts',
      StoriesScreen() => 'Stories',
      NotificationsScreen() => 'Notifications',
      _ => 'Unknown',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return const SizedBox.shrink();

    final unreadAsync = ref.watch(
      unreadNotificationsCountProvider(currentUser.uid),
    );
    final currentIndex = ref.watch(currentIndexProvider);

    final unreadCount = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);

    return CoolScaffold(
      body: PageView(
        controller: _pageController,
        pageSnapping: true,
        children: _pages,
      ),
      bottomNavigationBar: CoolBottomNavigationBar(
        items:
            _pages.map((page) {
              return CoolBottomNavItem(
                icon: _getPageIcon(page),
                label: _getPageLabel(page),
                badge:
                    (page is NotificationsScreen && unreadCount > 0)
                        ? CoolBadge(text: unreadCount.toString())
                        : null,
              );
            }).toList(),
        currentIndex: currentIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton:
          currentIndex == 2
              ? null
              : CoolFloatingButton(
                icon: LucideIcons.focus,
                onPressed: _onFabTap,
              ),
    );
  }
}
