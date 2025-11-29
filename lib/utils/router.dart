import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/screens/main_navigation.dart';
import '../providers/auth_provider.dart';
import '../auth_screens/login_screen.dart';
import '../auth_screens/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../info/zap/zap_detail_screen.dart';
import '../info/bookmarks/bookmarks_screen.dart';
import '../info/settings/settings_screen.dart';
import '../info/feedback/feedback_screen.dart';
import '../info/terms/terms_screen.dart';
import '../info/privacy/privacy_screen.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import '../screens/sharing/sharing_selection_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../providers/profile_provider.dart';
import '../services/notifications/fcm_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);
  final routerKey = GlobalKey<NavigatorState>();
  late final GoRouter router;

  router = GoRouter(
    navigatorKey: routerKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isGoingToAuth =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      // If not authenticated and trying to access protected routes
      if (!isAuthenticated && !isGoingToAuth) {
        return '/login';
      }

      // If authenticated and trying to access auth pages, redirect to home
      if (isAuthenticated && isGoingToAuth) {
        return '/';
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const MainNavigation()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/chat/:senderId',
        builder: (context, state) {
          final senderId = state.pathParameters['senderId'] ?? '';
          return ChatRouteWrapper(senderId: senderId);
        },
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/zap/:zapId',
        builder: (context, state) {
          final zapId = state.pathParameters['zapId'] ?? '';
          return ZapDetailScreen(zapId: zapId);
        },
      ),
      GoRoute(
        path: '/bookmarks',
        builder: (context, state) => const BookmarksScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/share',
        builder: (context, state) {
          // Get shared files from extra state
          final extra = state.extra;
          if (extra is List<SharedMediaFile>) {
            return SharingSelectionScreen(sharedFiles: extra);
          }
          return const Scaffold(
            body: Center(child: Text('No shared content')),
          );
        },
      ),
    ],
    errorBuilder:
        (context, state) =>
            Scaffold(body: Center(child: Text('Error: ${state.error}'))),
  );

  // Set up FCM navigation handler after router is created
  FCMNavigationHandler.navigateToChat = (String senderId) {
    Future.microtask(() {
      router.go('/chat/$senderId');
    });
  };

  return router;
});

/// A [Listenable] that rebuilds the router when auth state changes.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    // Listen to auth state changes
    _subscription = _ref.listen(currentUserProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// Wrapper widget for chat route that fetches user profile
class ChatRouteWrapper extends ConsumerWidget {
  final String senderId;

  const ChatRouteWrapper({super.key, required this.senderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final userAsync = ref.watch(userProfileProvider(senderId));

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('User not found')),
            body: const Center(child: Text('User not found')),
          );
        }
        return ChatScreen(
          currentUserId: currentUser.uid,
          otherUserId: senderId,
          otherUser: user,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}
