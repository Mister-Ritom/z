import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/social/profile_service.dart';
import '../models/user_model.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final userProfileProvider = FutureProvider.family<UserModel?, String>((
  ref,
  userId,
) {
  final profileService = ref.read(profileServiceProvider);
  return profileService.getProfileByUserId(userId);
});

final userByUsernameProvider = FutureProvider.family<UserModel?, String>((
  ref,
  username,
) async {
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.getUserByUsername(username);
});

final userFollowersProvider = FutureProvider.family<List<String>, String>((
  ref,
  userId,
) async {
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.getUserFollowers(userId);
});

final userFollowingProvider = FutureProvider.family<List<String>, String>((
  ref,
  userId,
) async {
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.getUserFollowing(userId);
});

final searchUsersProvider = FutureProvider.family<List<UserModel>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.searchUsers(query);
});
