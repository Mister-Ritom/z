import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final userProfileProvider = StreamProvider.family<UserModel?, String>((
  ref,
  userId,
) {
  final authService = ref.read(authServiceProvider);
  return authService.getUserByIdStream(userId);
});

final isFollowingProvider = FutureProvider.family<bool, Map<String, String>>((
  ref,
  params,
) async {
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.isFollowing(
    params['currentUserId']!,
    params['targetUserId']!,
  );
});

final userFollowersProvider = StreamProvider.family<List<String>, String>((
  ref,
  userId,
) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getUserFollowers(userId);
});

final userFollowingProvider = StreamProvider.family<List<String>, String>((
  ref,
  userId,
) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getUserFollowing(userId);
});

final searchUsersProvider = FutureProvider.family<List<UserModel>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.searchUsers(query);
});
