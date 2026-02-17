import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/profile_provider.dart';
import '../services/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
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
