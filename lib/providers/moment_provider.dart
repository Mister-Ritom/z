import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/moment_model.dart';
import 'package:z/services/content/moments/moment_service.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';

final momentServiceProvider = Provider<MomentService>((ref) {
  return MomentService();
});

final userMomentsProvider = StreamProvider.family<List<MomentModel>, String>((
  ref,
  userId,
) {
  final service = ref.watch(momentServiceProvider);
  return service.getUserMoments(userId);
});

// Provides the "Moments Rail" content
// Provides the "Moments Rail" content
final momentsRailProvider = StreamProvider<List<MomentModel>>((ref) {
  final service = ref.watch(momentServiceProvider);
  final currentUser = ref.watch(currentUserProvider).valueOrNull;

  if (currentUser == null) return Stream.value([]);

  final followingAsync = ref.watch(userFollowingProvider(currentUser.uid));

  return followingAsync.when(
    data: (followingIds) {
      // Also include own moments
      return service.getMomentsFeed(
        followingIds: followingIds,
        currentUserId: currentUser.uid,
      );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
