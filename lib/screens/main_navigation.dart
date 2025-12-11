import 'dart:async';
import 'dart:developer';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/settings_provider.dart';
import 'package:z/screens/home/home_screen.dart';
import 'package:z/screens/search/search_screen.dart';
import 'package:z/screens/shorts/shorts_screen.dart';
import 'package:z/screens/stories/stories_screen.dart';
import 'package:z/screens/notifications/notifications_screen.dart';
import 'package:z/providers/notification_provider.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/screens/stories/story_creation_screen.dart';
import 'package:z/widgets/zap/composer/zap_composer.dart';

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
    const ShortsScreen(),
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
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (index == 4 && currentUser != null) {
      _markNotificationsRead(currentUser.uid);
    }
    setState(() => _currentIndex = index);
  }

  void _onFabTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                _currentIndex == 3
                    ? const StoryCreationScreen()
                    : const ZapComposer(),
      ),
    );
  }

  Icon _getFabIcon() {
    return Icon(
      _currentIndex == 3 ? Icons.camera : Icons.edit,
      color: Theme.of(context).colorScheme.surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final glassMorphismEnabled =
        ref.watch(settingsProvider).glassMorphismEnabled;
    if (currentUser == null) return const SizedBox.shrink();

    final unreadAsync = ref.watch(
      unreadNotificationsCountProvider(currentUser.uid),
    );

    final unreadCount = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);

    return AdaptiveScaffold(
      body: _pages[_currentIndex],
      floatingActionButton:
          _currentIndex != 2
              ? Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: AdaptiveFloatingActionButton(
                  onPressed: _onFabTap,
                  child: _getFabIcon(),
                ),
              )
              : null,
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: glassMorphismEnabled,
        bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.house), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_fill),
              label: "Shorts",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.book), label: "Stories"),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: "Notifications",
            ),
          ],
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
        ),
        items: [
          AdaptiveNavigationDestination(icon: 'house.fill', label: 'Home'),
          AdaptiveNavigationDestination(
            icon: 'magnifyingglass',
            label: 'Search',
          ),
          AdaptiveNavigationDestination(icon: 'play', label: 'Shorts'),
          AdaptiveNavigationDestination(icon: 'book', label: 'Stories'),
          AdaptiveNavigationDestination(
            icon: 'bell.fill',
            label: unreadCount > 0 ? 'Alerts ($unreadCount)' : 'Alerts',
          ),
        ],
        selectedIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
