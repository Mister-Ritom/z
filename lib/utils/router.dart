import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/screens/sharing/sharing_screen.dart';
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
import '../screens/messages/chat_screen.dart';
import '../services/notifications/fcm_service.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../providers/settings_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);
  final routerKey = GlobalKey<NavigatorState>();
  late final GoRouter router;

  router = GoRouter(
    navigatorKey: routerKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      // Redirect file:// URIs to sharing screen (e.g., when sharing files to the app)
      if (state.uri.scheme == 'file') {
        // Extract the file path from the URI (remove the file:// scheme)
        // For file:// URIs, uri.path gives us the actual file path
        final filePath = state.uri.path;
        final encodedPath = Uri.encodeComponent(filePath);
        return '/sharing?file=$encodedPath';
      }

      final isAuthenticated = authState.valueOrNull != null;
      final settings = ref.read(settingsProvider);
      final hasSeenOnboarding = settings.hasSeenOnboarding;

      // Ensure we don't block the onboarding route itself
      if (state.matchedLocation == '/onboarding') {
        return null;
      }

      if (!hasSeenOnboarding) {
        return '/onboarding';
      }

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
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
        path: '/chat/:otherUserId',
        builder: (context, state) {
          final otherUserId = state.pathParameters['otherUserId'] ?? '';
          return ChatScreen(otherUserId: otherUserId);
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
        path: '/sharing',
        builder: (context, state) {
          // Check if we have a file query parameter (from file:// URI redirect)
          final fileParam = state.uri.queryParameters['file'];
          if (fileParam != null) {
            // Decode the file path from the query parameter
            final filePath = Uri.decodeComponent(fileParam);
            return SharingScreen([filePath]);
          }
          // Otherwise, use the extra data (from normal sharing flow)
          final mediaUrls = state.extra as List<String>? ?? [];
          return SharingScreen(mediaUrls);
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
    ],
    errorBuilder: (context, state) {
      return Scaffold(body: Center(child: Text('Error: ${state.error}')));
    },
  );

  // Set up FCM navigation handler after router is created
  FCMNavigationHandler.navigateToChat = (String otherUserId) {
    Future.microtask(() {
      router.go('/chat/$otherUserId');
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
    _settingsSubscription = _ref.listen(settingsProvider, (previous, next) {
      if (previous?.hasSeenOnboarding != next.hasSeenOnboarding) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
  late final ProviderSubscription _subscription;
  late final ProviderSubscription _settingsSubscription;

  @override
  void dispose() {
    _subscription.close();
    _settingsSubscription.close();
    super.dispose();
  }
}
