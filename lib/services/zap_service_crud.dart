part of 'zap_service.dart';

mixin _ZapServiceCrud on _ZapServiceBase {
  Future<List<ZapModel>> searchZaps(String query) async {
    try {
      final lowerQuery = query.toLowerCase();

      final hashtagResults =
          await _collection
              .where('hashtags', arrayContains: lowerQuery)
              .where('isDeleted', isEqualTo: false)
              .get();

      final mentionResults =
          await _collection
              .where('mentions', arrayContains: lowerQuery)
              .where('isDeleted', isEqualTo: false)
              .get();

      final textResults =
          await _collection
              .where('isDeleted', isEqualTo: false)
              .orderBy('text')
              .startAt([lowerQuery])
              .endAt(['$lowerQuery\uf8ff'])
              .get();

      final allDocs = [
        ...hashtagResults.docs,
        ...mentionResults.docs,
        ...textResults.docs,
      ];
      final uniqueDocs = {for (var doc in allDocs) doc.id: doc}.values.toList();

      final zaps =
          uniqueDocs
              .map((doc) {
                if (doc.exists) {
                  return ZapModel.fromMap({'id': doc.id, ...doc.data() as Map});
                }
                return null;
              })
              .whereType<ZapModel>()
              .toList();

      zaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      AppLogger.info(
        'ZapService',
        'Zap search completed',
        data: {'query': query, 'resultsCount': zaps.length, 'isShort': isShort},
      );
      return zaps;
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error searching zaps',
        error: e,
        stackTrace: st,
        data: {'query': query, 'isShort': isShort},
      );
      throw Exception('Failed to search zaps: $e');
    }
  }

  Future<ZapModel> createZap({
    required String zapId,
    required String userId,
    required String text,
    List<String> mediaUrls = const [],
    String? parentZapId,
    String? quotedZapId,
  }) async {
    try {
      final effectiveParentId = isShort ? null : parentZapId;
      final effectiveQuotedId = isShort ? null : quotedZapId;

      final hashtags = Helpers.extractHashtags(text);
      final mentions = Helpers.extractMentions(text);

      final zap = ZapModel(
        id: zapId,
        userId: userId,
        parentZapId: effectiveParentId,
        quotedZapId: effectiveQuotedId,
        text: text,
        mediaUrls: mediaUrls,
        createdAt: DateTime.now(),
        hashtags: hashtags,
        mentions: mentions,
        isShort: isShort,
      );

      await _collection.doc(zap.id).set(zap.toMap());

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'zapsCount': FieldValue.increment(1)});

      if (!isShort && effectiveParentId != null) {
        await _firestore
            .collection(AppConstants.zapsCollection)
            .doc(effectiveParentId)
            .update({'repliesCount': FieldValue.increment(1)});

        final parentZap = await getZapById(effectiveParentId);
        if (parentZap != null && parentZap.userId != userId) {
          await Helpers.createNotification(
            userId: parentZap.userId,
            fromUserId: userId,
            type: NotificationType.reply,
            zapId: zap.id,
          );
        }
      }

      for (final mention in mentions) {
        final mentionedUsername = mention.substring(1);
        final mentionedUser = await _getUserByUsername(mentionedUsername);
        final mentionedUserId = mentionedUser?['id'] as String?;
        if (mentionedUserId != null && mentionedUserId != userId) {
          await Helpers.createNotification(
            userId: mentionedUserId,
            fromUserId: userId,
            type: NotificationType.mention,
            zapId: zap.id,
          );
        }
      }

      AppLogger.info(
        'ZapService',
        'Zap created successfully',
        data: {
          'zapId': zap.id,
          'userId': userId,
          'isShort': isShort,
          'hasMedia': mediaUrls.isNotEmpty,
        },
      );
      return zap;
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error creating zap',
        error: e,
        stackTrace: st,
        data: {'userId': userId, 'isShort': isShort},
      );
      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to create zap',
        fatal: false,
      );
      throw Exception('Failed to create zap: $e');
    }
  }

  Future<ZapModel?> getZapById(String zapId) async {
    try {
      final doc = await _collection.doc(zapId).get();
      if (!doc.exists || doc.data() == null) {
        AppLogger.warn(
          'ZapService',
          'Zap not found',
          data: {'zapId': zapId, 'isShort': isShort},
        );
        return null;
      }
      return ZapModel.fromMap({'id': doc.id, ...doc.data() as Map});
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error fetching zap by ID',
        error: e,
        stackTrace: st,
        data: {'zapId': zapId, 'isShort': isShort},
      );
      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to fetch zap by ID',
        fatal: false,
      );
      return null;
    }
  }

  Future<void> deleteZap(String zapId) async {
    try {
      await _collection.doc(zapId).update({'isDeleted': true});
      AppLogger.info(
        'ZapService',
        'Zap deleted successfully',
        data: {'zapId': zapId, 'isShort': isShort},
      );
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error deleting zap',
        error: e,
        stackTrace: st,
        data: {'zapId': zapId, 'isShort': isShort},
      );
      throw Exception('Failed to delete zap: $e');
    }
  }

  Future<void> bookmarkZap(String zapId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.bookmarksCollection)
          .doc('${userId}_$zapId')
          .set({'userId': userId, 'zapId': zapId, 'createdAt': DateTime.now()});
      AppLogger.info(
        'ZapService',
        'Zap bookmarked successfully',
        data: {'zapId': zapId, 'userId': userId},
      );
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error bookmarking zap',
        error: e,
        stackTrace: st,
        data: {'zapId': zapId, 'userId': userId},
      );
      throw Exception('Failed to bookmark zap: $e');
    }
  }

  Future<void> removeBookmark(String zapId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.bookmarksCollection)
          .doc('${userId}_$zapId')
          .delete();
      AppLogger.info(
        'ZapService',
        'Bookmark removed successfully',
        data: {'zapId': zapId, 'userId': userId},
      );
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error removing bookmark',
        error: e,
        stackTrace: st,
        data: {'zapId': zapId, 'userId': userId},
      );
      throw Exception('Failed to remove bookmark: $e');
    }
  }

  Future<bool> isBookmarked(String zapId, String userId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.bookmarksCollection)
              .doc('${userId}_$zapId')
              .get();
      return doc.exists;
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error checking bookmark',
        error: e,
        stackTrace: st,
        data: {'zapId': zapId, 'userId': userId},
      );
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getUserByUsername(String username) async {
    try {
      final query =
          await _firestore
              .collection(AppConstants.usersCollection)
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

      if (query.docs.isEmpty) return null;
      final doc = query.docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error getting user by username',
        error: e,
        stackTrace: st,
        data: {'username': username},
      );
      return null;
    }
  }
}
