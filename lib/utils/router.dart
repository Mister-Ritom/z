import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/tweet/tweet_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);
  final routerKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: routerKey,
    initialLocation: '/home',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isGoingToAuth =
          state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      // If not authenticated and trying to access protected routes
      if (!isAuthenticated && !isGoingToAuth) {
        return '/login';
      }

      // If authenticated and trying to access auth pages, redirect to home
      if (isAuthenticated && isGoingToAuth) {
        return '/home';
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
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
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/tweet/:tweetId',
        builder: (context, state) {
          final tweetId = state.pathParameters['tweetId'] ?? '';
          return TweetDetailScreen(tweetId: tweetId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
});

/// A [Listenable] that rebuilds the router when auth state changes.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    // Listen to auth state changes
    _subscription = _ref.listen(
      currentUserProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }

  final Ref _ref;
  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

