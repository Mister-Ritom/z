import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:z/screens/home/home_screen.dart';
import 'package:z/screens/search/search_screen.dart';
import 'package:z/screens/reels/reels_screen.dart';
import 'package:z/screens/stories/stories_screen.dart';
import 'package:z/screens/notifications/notifications_screen.dart';
import 'package:z/providers/notification_provider.dart';
import 'package:z/providers/auth_provider.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    SearchScreen(),
    ReelsScreen(),
    StoriesScreen(),
    NotificationsScreen(),
  ];

  void _markNotificationsRead(String userId) {
    try {
      unawaited(markAllNotificationsAsRead(userId));
      log('✅ Marked notifications as read for user $userId');
    } catch (e, st) {
      log("❌ Error setting notifications to read", error: e, stackTrace: st);
    }
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    final currentUser = ref.read(currentUserModelProvider).valueOrNull;

    // 🔔 When user opens Notifications tab, mark all as read
    if (index == 4 && currentUser != null) {
      _markNotificationsRead(currentUser.id);
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          border: Border(
            top: BorderSide(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.grey.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_pages.length, (index) {
            final isSelected = index == _currentIndex;
            final color =
                isSelected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6);

            IconData icon;
            switch (index) {
              case 0:
                icon = Icons.home_rounded;
                break;
              case 1:
                icon = Icons.search_rounded;
                break;
              case 2:
                icon = Icons.play_circle_fill_rounded;
                break;
              case 3:
                icon = Icons.auto_stories_rounded;
                break;
              case 4:
                icon = Icons.notifications_rounded;
                break;
              default:
                icon = Icons.circle;
            }

            // Notifications tab → show badge
            if (index == 4 && currentUser != null) {
              final notificationsAsync = ref.watch(
                unreadNotificationsCountProvider(currentUser.id),
              );

              return Expanded(
                child: notificationsAsync.when(
                  data:
                      (count) => _buildNavItem(
                        index: index,
                        icon: icon,
                        color: color,
                        isSelected: isSelected,
                        onTap: () => _onItemTapped(index),
                        badgeCount: count,
                      ),
                  loading:
                      () => _buildNavItem(
                        index: index,
                        icon: icon,
                        color: color,
                        isSelected: isSelected,
                        onTap: () => _onItemTapped(index),
                      ),
                  error: (e, st) {
                    log('Error loading unread notifications', error: e);
                    return _buildNavItem(
                      index: index,
                      icon: icon,
                      color: color,
                      isSelected: isSelected,
                      onTap: () => _onItemTapped(index),
                    );
                  },
                ),
              );
            }

            // Normal tabs
            return Expanded(
              child: _buildNavItem(
                index: index,
                icon: icon,
                color: color,
                isSelected: isSelected,
                onTap: () => _onItemTapped(index),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color:
              isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: isSelected ? 28 : 24),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        final offsetAnim = Tween<Offset>(
                          begin: const Offset(0, -0.1),
                          end: Offset.zero,
                        ).animate(animation);
                        return SlideTransition(
                          position: offsetAnim,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey<int>(badgeCount),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isSelected ? 1 : 0,
              child: Text(
                _getLabel(index),
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLabel(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Search';
      case 2:
        return 'Reels';
      case 3:
        return 'Stories';
      case 4:
        return 'Alerts';
      default:
        return '';
    }
  }
}
