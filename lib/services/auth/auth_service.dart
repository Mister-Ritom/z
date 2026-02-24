import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';

class AuthService {
  final Ref ref;

  AuthService(this.ref);

  final _auth = Database.client.auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((s) => s.session?.user);

  // Sign up with email and password
  Future<UserModel?> _createUserProfileFromAuthResponse({
    required User user,
    required String username,
    required String displayName,
  }) async {
    final profileService = ref.read(profileServiceProvider);
    final userModel = UserModel(
      id: user.id,
      username: username,
      displayName: displayName,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await profileService.createProfile(userModel);
    return userModel;
  }

  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      final signUpResponse = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': displayName, 'username': username},
      );

      final user = signUpResponse.user;

      if (user == null) return null;

      return await _createUserProfileFromAuthResponse(
        user: user,
        username: username,
        displayName: displayName,
      );
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final signInResponse = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (signInResponse.user == null) return null;
      final String id = signInResponse.user!.id;
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getProfileByUserId(id);
      return profile;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  // Sign in with Google

  Future<UserModel?> signInWithGoogle() async {
    await _googleSignIn.initialize();
    final googleCred = await _googleSignIn.authenticate();
    final scopes = ['email', 'profile'];
    final authorizationStatus =
        await googleCred.authorizationClient.authorizationForScopes(scopes) ??
        await googleCred.authorizationClient.authorizeScopes(scopes);
    final idToken = googleCred.authentication.idToken;
    final accessToken = authorizationStatus.accessToken;
    if (idToken == null) {
      AppLogger.error(
        "Google Auth-> AuthService",
        "Google sign in id token is null, aborting sign in",
      );
      return null;
    }

    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    final user = response.user;

    if (user == null) return null;
    final profileService = ref.read(profileServiceProvider);
    final String displayName = user.userMetadata?["full_name"] ?? "No Name";
    var username = displayName.replaceAll(" ", "_");
    username = await profileService.getAvailableUsername(username);

    return _createUserProfileFromAuthResponse(
      user: user,
      username: username,
      displayName: displayName,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Resend email confirmation
  Future<void> resendEmailConfirmation(String email) async {
    try {
      await _auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      throw Exception('Failed to resend confirmation email: $e');
    }
  }

  // Refresh user session to check for updated auth state (like email confirmation)
  Future<void> refreshUserSession() async {
    try {
      await _auth.refreshSession();
    } catch (e) {
      // If refresh fails, it might be because the user is not logged in yet
      AppLogger.warn('AuthService', 'Session refresh failed: $e');
    }
  }
}
