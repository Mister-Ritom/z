import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

import 'package:z/screens/home/home_screen.dart';
import 'package:z/screens/search/search_screen.dart';
import 'package:z/screens/reels/reels_screen.dart';
import 'package:z/screens/stories/stories_screen.dart';
import 'package:z/screens/notifications/notifications_screen.dart';
import 'package:z/providers/notification_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/glass_widget.dart';
import 'package:z/widgets/tweet_composer.dart';

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
  int _currentIndex = 0;

  List<Widget> get _pages => [
    const HomeScreen(),
    const SearchScreen(),
    ReelsScreen(isActive: _currentIndex == 2),
    const StoriesScreen(),
    const NotificationsScreen(),
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
      bottomNavigationBar:
          (!Helpers.isGlassSupported)
              ? _buildWebNav(theme, isDark, currentUser)
              : _buildMobileGlassNav(theme, isDark, currentUser),
      floatingActionButton: GlassFAB(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TweetComposer()),
          );
        },
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildWebNav(ThemeData theme, bool isDark, dynamic currentUser) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      height: 70,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacityAlpha(0.05),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacityAlpha(0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_pages.length, (index) {
          final isSelected = index == _currentIndex;
          final color =
              isSelected
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onSurface.withOpacityAlpha(0.6);
          final icon = _getIcon(index);

          return Expanded(
            child: GestureDetector(
              onTap: () => _onItemTapped(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: isSelected ? 28 : 24),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isSelected ? 1 : 0,
                    child: Text(
                      _getLabel(index),
                      style: TextStyle(
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
        }),
      ),
    );
  }

  // 📱 MOBILE (Android/iOS) GLASS NAVIGATION
  Widget _buildMobileGlassNav(
    ThemeData theme,
    bool isDark,
    dynamic currentUser,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: OCLiquidGlassGroup(
        settings: OCLiquidGlassSettings(
          refractStrength: -0.07,
          blurRadiusPx: 8.0,
          specStrength: 25.0,
          lightbandColor: isDark ? Colors.cyanAccent : Colors.blueAccent,
        ),
        child: OCLiquidGlass(
          width: double.infinity,
          height: 78,
          borderRadius: 24,
          color:
              isDark
                  ? Colors.white.withOpacityAlpha(0.05)
                  : Colors.black.withOpacityAlpha(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_pages.length, (index) {
                final isSelected = index == _currentIndex;
                final color =
                    isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface.withOpacityAlpha(0.6);
                final icon = _getIcon(index);

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
                      error:
                          (_, __) => _buildNavItem(
                            index: index,
                            icon: icon,
                            color: color,
                            isSelected: isSelected,
                            onTap: () => _onItemTapped(index),
                          ),
                    ),
                  );
                }

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
        ),
      ),
    );
  }

  // 🔸 NAV ITEM
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
        child: OCLiquidGlass(
          width: double.infinity,
          height: 52,
          borderRadius: 18,
          color: isSelected ? color.withOpacityAlpha(0.2) : Colors.transparent,
          child: Column(
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
                      child: _buildBadge(badgeCount),
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
      ),
    );
  }

  // 🔔 Badge
  Widget _buildBadge(int count) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(count),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12, width: 1),
        ),
        child: Center(
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_rounded;
      case 1:
        return Icons.search_rounded;
      case 2:
        return Icons.play_circle_fill_rounded;
      case 3:
        return Icons.auto_stories_rounded;
      case 4:
        return Icons.notifications_rounded;
      default:
        return Icons.circle;
    }
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
