import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/profile_provider.dart';
import '../services/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';

import '../services/analytics/analytics_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return AuthService(ref, analytics: analytics);
});

final currentUserProvider = StreamProvider<sb.User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.asyncMap((user) async {
    if (user == null) return null;
    final profileService = ref.read(profileServiceProvider);
    return await profileService.getProfileByUserId(user.id);
  });
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  return currentUserAsync.valueOrNull != null &&
      currentUserAsync.valueOrNull?.emailConfirmedAt != null;
});

final pendingEmailProvider = StateProvider<String?>((ref) => null);
final pendingPasswordProvider = StateProvider<String?>((ref) => null);

extension UserExtension on sb.User {
  bool get isEmailVerified => emailConfirmedAt != null;
  String? get displayName => userMetadata?['full_name'];
  String get username => userMetadata?['username'] ?? "";
  String? get profilePictureUrl => userMetadata?['profile_picture_url'];
}
