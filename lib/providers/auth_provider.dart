import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth/auth_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.asyncMap((user) async {
    if (user == null) return null;
    return await authService.getUserById(user.uid);
  });
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  return currentUserAsync.valueOrNull != null;
});
