import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      // Create user with email/password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) return null;

      // Create user document in Firestore
      final userModel = UserModel(
        id: userCredential.user!.uid,
        email: email,
        username: username,
        displayName: displayName,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userCredential.user!.uid)
          .set(userModel.toMap());

      return userModel;
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
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) return null;

      return await getUserById(userCredential.user!.uid);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<UserCredential> _googleCred() async {
    if (kIsWeb) {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      return await FirebaseAuth.instance.signInWithPopup(googleProvider);
    }
    // Trigger the authentication flow
    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Once signed in, return the UserCredential
    return await _auth.signInWithCredential(credential);
  }

  // Sign in with Google

  Future<UserModel?> signInWithGoogle() async {
    try {
      final userCredential = await _googleCred();

      if (userCredential.user == null) return null;

      final user = userCredential.user!;
      final userDoc =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        // Generate a base username from display name
        String baseUsername = (user.displayName ?? 'user')
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '_')
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');

        // Make sure it's not empty
        if (baseUsername.isEmpty) baseUsername = 'user';

        // Check username availability and modify until available
        String finalUsername = baseUsername;
        final random = Random();
        bool available = await isUsernameAvailable(finalUsername);

        while (!available) {
          final randomSuffix = random.nextInt(9999);
          finalUsername = '$baseUsername$randomSuffix';
          available = await isUsernameAvailable(finalUsername);
        }

        // Create the new user document
        final userModel = UserModel(
          id: user.uid,
          email: user.email ?? '',
          username: finalUsername,
          displayName: user.displayName ?? '',
          profilePictureUrl: user.photoURL,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(userModel.toMap());

        return userModel;
      }

      return await getUserById(user.uid);
    } catch (e) {
      // 🧠 Ignore user-cancelled sign-in
      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('user_cancelled') ||
          e.toString().contains('The user canceled the sign-in flow')) {
        return null;
      } else {
        throw Exception('Google sign in failed: $e');
      }
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .get();

      if (!doc.exists) return null;

      return UserModel.fromMap({'id': doc.id, ...doc.data()!});
    } catch (e) {
      return null;
    }
  }

  // Get user by ID as stream (for real-time updates)
  Stream<UserModel?> getUserByIdStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserModel.fromMap({'id': doc.id, ...doc.data()!});
        });
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final query =
          await _firestore
              .collection(AppConstants.usersCollection)
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

      return query.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }
}
