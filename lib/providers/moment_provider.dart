import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/moment_model.dart';
import 'package:z/services/content/moments/moment_service.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';

final momentServiceProvider = Provider<MomentService>((ref) {
  return MomentService();
});

final userMomentsProvider = FutureProvider.family<List<MomentModel>, String>((
  ref,
  userId,
) async {
  final service = ref.watch(momentServiceProvider);
  return await service.getUserMoments(userId);
});

// Provides the "Moments Rail" content
final momentsRailProvider = FutureProvider<List<MomentModel>>((ref) async {
  final service = ref.watch(momentServiceProvider);
  final currentUser = ref.watch(currentUserProvider).valueOrNull;

  if (currentUser == null) return [];

  final followingAsync = ref.watch(userFollowingProvider(currentUser.id));

  return followingAsync.when(
    data: (followingIds) async {
      // Also include own moments
      return await service.getMomentsFeed(
        followingIds: followingIds,
        currentUserId: currentUser.id,
      );
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
