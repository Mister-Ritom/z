import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/models/block_model.dart';
import 'package:z/utils/logger.dart';

class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Block a specific post/short
  Future<void> blockPost({
    required String blockerId,
    required String postId,
    bool isShort = false,
  }) async {
    try {
      final block = BlockModel(
        id: _firestore.collection('blocks').doc().id,
        blockerId: blockerId,
        blockType: BlockType.post,
        blockedPostId: postId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('blocks')
          .doc(block.id)
          .set(block.toMap());

      // Also store in user's blocked posts collection for quick lookup
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_posts')
          .doc(postId)
          .set({
        'postId': postId,
        'isShort': isShort,
        'blockedAt': DateTime.now(),
      });

      AppLogger.info(
        'BlockService',
        'Post blocked successfully',
        data: {'blockerId': blockerId, 'postId': postId, 'isShort': isShort},
      );
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error blocking post',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to block post: $e');
    }
  }

  /// Block a user for zaps/shorts (affects recommendations)
  Future<void> blockUserForContent({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final block = BlockModel(
        id: _firestore.collection('blocks').doc().id,
        blockerId: blockerId,
        blockType: BlockType.userContent,
        blockedUserId: blockedUserId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('blocks')
          .doc(block.id)
          .set(block.toMap());

      // Also store in user's blocked users collection for quick lookup
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_users_content')
          .doc(blockedUserId)
          .set({
        'blockedUserId': blockedUserId,
        'blockedAt': DateTime.now(),
      });

      AppLogger.info(
        'BlockService',
        'User blocked for content successfully',
        data: {'blockerId': blockerId, 'blockedUserId': blockedUserId},
      );
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error blocking user for content',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to block user for content: $e');
    }
  }

  /// Block a user for messaging only (doesn't affect recommendations)
  Future<void> blockUserForMessaging({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final block = BlockModel(
        id: _firestore.collection('blocks').doc().id,
        blockerId: blockerId,
        blockType: BlockType.userMessaging,
        blockedUserId: blockedUserId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('blocks')
          .doc(block.id)
          .set(block.toMap());

      // Also store in user's blocked messaging users collection
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_users_messaging')
          .doc(blockedUserId)
          .set({
        'blockedUserId': blockedUserId,
        'blockedAt': DateTime.now(),
      });

      AppLogger.info(
        'BlockService',
        'User blocked for messaging successfully',
        data: {'blockerId': blockerId, 'blockedUserId': blockedUserId},
      );
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error blocking user for messaging',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to block user for messaging: $e');
    }
  }

  /// Unblock a post
  Future<void> unblockPost({
    required String blockerId,
    required String postId,
  }) async {
    try {
      // Remove from blocks collection
      final blocksSnapshot = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: blockerId)
          .where('blockType', isEqualTo: 'post')
          .where('blockedPostId', isEqualTo: postId)
          .get();

      for (var doc in blocksSnapshot.docs) {
        await doc.reference.delete();
      }

      // Remove from user's blocked posts collection
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_posts')
          .doc(postId)
          .delete();

      AppLogger.info(
        'BlockService',
        'Post unblocked successfully',
        data: {'blockerId': blockerId, 'postId': postId},
      );
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error unblocking post',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to unblock post: $e');
    }
  }

  /// Unblock a user for content
  Future<void> unblockUserForContent({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      // Remove from blocks collection
      final blocksSnapshot = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: blockerId)
          .where('blockType', isEqualTo: 'userContent')
          .where('blockedUserId', isEqualTo: blockedUserId)
          .get();

      for (var doc in blocksSnapshot.docs) {
        await doc.reference.delete();
      }

      // Remove from user's blocked users collection
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_users_content')
          .doc(blockedUserId)
          .delete();

      AppLogger.info(
        'BlockService',
        'User unblocked for content successfully',
        data: {'blockerId': blockerId, 'blockedUserId': blockedUserId},
      );
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error unblocking user for content',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to unblock user for content: $e');
    }
  }

  /// Unblock a user for messaging
  Future<void> unblockUserForMessaging({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      // Remove from blocks collection
      final blocksSnapshot = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: blockerId)
          .where('blockType', isEqualTo: 'userMessaging')
          .where('blockedUserId', isEqualTo: blockedUserId)
          .get();

      for (var doc in blocksSnapshot.docs) {
        await doc.reference.delete();
      }

      // Remove from user's blocked messaging users collection
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_users_messaging')
          .doc(blockedUserId)
          .delete();

      AppLogger.info(
        'BlockService',
        'User unblocked for messaging successfully',
        data: {'blockerId': blockerId, 'blockedUserId': blockedUserId},
      );
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error unblocking user for messaging',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to unblock user for messaging: $e');
    }
  }

  /// Get all blocked post IDs for a user
  Future<Set<String>> getBlockedPostIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('blocked_posts')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error getting blocked post IDs',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  /// Get all blocked user IDs for content
  Future<Set<String>> getBlockedUserIdsForContent(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('blocked_users_content')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error getting blocked user IDs for content',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  /// Get all blocked user IDs for messaging
  Future<Set<String>> getBlockedUserIdsForMessaging(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('blocked_users_messaging')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error getting blocked user IDs for messaging',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  /// Check if a post is blocked
  Future<bool> isPostBlocked({
    required String userId,
    required String postId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('blocked_posts')
          .doc(postId)
          .get();

      return doc.exists;
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error checking if post is blocked',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Check if a user is blocked for content
  Future<bool> isUserBlockedForContent({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_users_content')
          .doc(blockedUserId)
          .get();

      return doc.exists;
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error checking if user is blocked for content',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Check if a user is blocked for messaging
  Future<bool> isUserBlockedForMessaging({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blocked_users_messaging')
          .doc(blockedUserId)
          .get();

      return doc.exists;
    } catch (e, st) {
      AppLogger.error(
        'BlockService',
        'Error checking if user is blocked for messaging',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}

