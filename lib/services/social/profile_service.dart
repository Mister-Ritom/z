import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/models/notification_model.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/models/user_model.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/logger.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update user profile
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? profilePictureUrl,
    String? coverPhotoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (displayName != null) updates['displayName'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (profilePictureUrl != null) {
        updates['profilePictureUrl'] = profilePictureUrl;
      }
      if (coverPhotoUrl != null) {
        updates['coverPhotoUrl'] = coverPhotoUrl;
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Follow user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Add to current user's following
        transaction.set(
          _firestore
              .collection(AppConstants.followingCollection)
              .doc(currentUserId)
              .collection('users')
              .doc(targetUserId),
          {'createdAt': FieldValue.serverTimestamp()},
        );

        // Add to target user's followers
        transaction.set(
          _firestore
              .collection(AppConstants.followersCollection)
              .doc(targetUserId)
              .collection('users')
              .doc(currentUserId),
          {'createdAt': FieldValue.serverTimestamp()},
        );

        // Update follower counts
        transaction.update(
          _firestore
              .collection(AppConstants.usersCollection)
              .doc(currentUserId),
          {'followingCount': FieldValue.increment(1)},
        );

        transaction.update(
          _firestore.collection(AppConstants.usersCollection).doc(targetUserId),
          {'followersCount': FieldValue.increment(1)},
        );
        await Helpers.createNotification(
          userId: targetUserId,
          fromUserId: currentUserId,
          type: NotificationType.follow,
        );
      });
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  // Unfollow user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Remove from current user's following
        transaction.delete(
          _firestore
              .collection(AppConstants.followingCollection)
              .doc(currentUserId)
              .collection('users')
              .doc(targetUserId),
        );

        // Remove from target user's followers
        transaction.delete(
          _firestore
              .collection(AppConstants.followersCollection)
              .doc(targetUserId)
              .collection('users')
              .doc(currentUserId),
        );

        // Update follower counts
        transaction.update(
          _firestore
              .collection(AppConstants.usersCollection)
              .doc(currentUserId),
          {'followingCount': FieldValue.increment(-1)},
        );

        transaction.update(
          _firestore.collection(AppConstants.usersCollection).doc(targetUserId),
          {'followersCount': FieldValue.increment(-1)},
        );
      });
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  // Check if user is following another user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.followingCollection)
              .doc(currentUserId)
              .collection('users')
              .doc(targetUserId)
              .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get user followers
  Stream<List<String>> getUserFollowers(String userId) {
    return _firestore
        .collection(AppConstants.followersCollection)
        .doc(userId)
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Get user following
  Stream<List<String>> getUserFollowing(String userId) {
    return _firestore
        .collection(AppConstants.followingCollection)
        .doc(userId)
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Search users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final searchLower = query.toLowerCase();
      final usersQuery =
          await _firestore
              .collection(AppConstants.usersCollection)
              .where('username', isGreaterThanOrEqualTo: searchLower)
              .where('username', isLessThanOrEqualTo: '$searchLower\uf8ff')
              .limit(AppConstants.usersPerPage)
              .get();

      return usersQuery.docs
          .map((doc) => UserModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> blockUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Create block record
        transaction.set(_firestore.collection('blocks').doc(), {
          'blockerId': currentUserId,
          'blockedId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Optimistically unfollow if blocking
        // (The logic is repetitive with unfollowUser but safe to duplicate or call if refactored.
        // For atomic safety, we just add the block record. A cloud function usually cleans up follows.)
      });
      AppLogger.info(
        'ProfileService',
        'User $currentUserId blocked $targetUserId',
      );
    } catch (e) {
      AppLogger.error('ProfileService', 'Error blocking user', error: e);
      rethrow;
    }
  }

  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(AppConstants.usersCollection)
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return UserModel.fromMap({'id': doc.id, ...doc.data()});
    } catch (e, s) {
      AppLogger.error(
        "ProfileService",
        'Failed to get user by username',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }
}
