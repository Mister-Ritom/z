import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/models/comment_model.dart';
import '../models/zap_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ZapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool isShort;

  ZapService({required this.isShort});

  CollectionReference get _collection => _firestore.collection(
    isShort ? AppConstants.shortsCollection : AppConstants.zapsCollection,
  );

  Query _zapQuery({bool parentOnly = true}) {
    Query query = _collection.where('isDeleted', isEqualTo: false);
    if (parentOnly && !isShort) {
      query = query.where('parentZapId', isNull: true);
    }
    return query;
  }

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
      return zaps;
    } catch (e, st) {
      log('Error searching zaps', error: e, stackTrace: st);
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
      // Shorts cannot have parent or quoted zaps
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

      // Replies only apply to normal zaps
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
        if (mentionedUser != null && mentionedUser.id != userId) {
          await Helpers.createNotification(
            userId: mentionedUser.id,
            fromUserId: userId,
            type: NotificationType.mention,
            zapId: zap.id,
          );
        }
      }

      return zap;
    } catch (e, st) {
      log('Error creating zap', error: e, stackTrace: st);
      throw Exception('Failed to create zap: $e');
    }
  }

  Future<ZapModel?> getZapById(String zapId) async {
    try {
      final doc = await _collection.doc(zapId).get();
      if (!doc.exists || doc.data() == null) return null;
      return ZapModel.fromMap({'id': doc.id, ...doc.data() as Map});
    } catch (e, st) {
      log('Error fetching zap by ID', error: e, stackTrace: st);
      return null;
    }
  }

  Stream<List<ZapModel>> getForYouFeed({DocumentSnapshot? lastDoc}) {
    try {
      Query query = _zapQuery()
          .orderBy('createdAt', descending: true)
          .limit(AppConstants.zapsPerPage);

      if (lastDoc != null) query = query.startAfterDocument(lastDoc);

      return query.snapshots().map(
        (snapshot) =>
            snapshot.docs
                .map((doc) {
                  if (doc.exists && doc.data() != null) {
                    return ZapModel.fromMap({
                      'id': doc.id,
                      ...doc.data() as Map,
                    }, snapshot: doc);
                  }
                  return null;
                })
                .whereType<ZapModel>()
                .toList(),
      );
    } catch (e, st) {
      log('Error getting for-you feed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Stream<List<ZapModel>> getFollowingFeed(String userId) {
    return _firestore
        .collection(AppConstants.followingCollection)
        .doc(userId)
        .collection('users')
        .snapshots()
        .asyncMap((followingSnapshot) async {
          if (followingSnapshot.docs.isEmpty) return <ZapModel>[];

          final followingIds =
              followingSnapshot.docs.map((doc) => doc.id).toList();
          final List<ZapModel> allZaps = [];

          for (int i = 0; i < followingIds.length; i += 10) {
            final batch = followingIds.sublist(
              i,
              i + 10 > followingIds.length ? followingIds.length : i + 10,
            );
            final zapsQuery =
                await _zapQuery()
                    .where('userId', whereIn: batch)
                    .orderBy('createdAt', descending: true)
                    .limit(AppConstants.zapsPerPage)
                    .get();

            allZaps.addAll(
              zapsQuery.docs
                  .map((doc) {
                    if (doc.exists && doc.data() != null) {
                      return ZapModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<ZapModel>()
                  .toList(),
            );
          }

          allZaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return allZaps.take(AppConstants.zapsPerPage).toList();
        });
  }

  Stream<List<ZapModel>> getUserZaps(String userId) {
    return _zapQuery()
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) {
                    if (doc.exists && doc.data() != null) {
                      return ZapModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<ZapModel>()
                  .toList(),
        );
  }

  Stream<List<ZapModel>> getZapReplies(String zapId) {
    if (isShort) return const Stream.empty();
    return _zapQuery(parentOnly: false)
        .where('parentZapId', isEqualTo: zapId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) {
                    if (doc.exists && doc.data() != null) {
                      return ZapModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<ZapModel>()
                  .toList(),
        );
  }

  // --- User Liked, Rezaped, Bookmarked Zaps ---
  Stream<List<ZapModel>> getUserLikedZaps(String userId) {
    return _collection
        .where('likedBy', arrayContains: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final zaps =
              snapshot.docs
                  .map((doc) {
                    if (doc.exists) {
                      return ZapModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<ZapModel>()
                  .toList();
          zaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return zaps;
        });
  }

  Stream<List<ZapModel>> getUserRezapedZaps(String userId) {
    return _collection
        .where('rezapedBy', arrayContains: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final zaps =
              snapshot.docs
                  .map((doc) {
                    if (doc.exists) {
                      return ZapModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<ZapModel>()
                  .toList();
          zaps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return zaps;
        });
  }

  Stream<List<ZapModel>> getUserBookmarkedZaps(String userId) {
    return _firestore
        .collection(AppConstants.bookmarksCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return <ZapModel>[];

          final zapIds =
              snapshot.docs
                  .map((d) => (d.data() as Map)['zapId'] as String)
                  .toList();

          final List<ZapModel> allZaps = [];
          for (int i = 0; i < zapIds.length; i += 10) {
            final batch = zapIds.sublist(
              i,
              i + 10 > zapIds.length ? zapIds.length : i + 10,
            );
            final zapsQuery =
                await _collection
                    .where('isDeleted', isEqualTo: false)
                    .where(FieldPath.documentId, whereIn: batch)
                    .get();

            allZaps.addAll(
              zapsQuery.docs
                  .map(
                    (doc) =>
                        ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
                  )
                  .toList(),
            );
          }

          final createdAtById = {
            for (final d in snapshot.docs)
              (d.data() as Map)['zapId'] as String:
                  (d.data() as Map)['createdAt'],
          };
          allZaps.sort((a, b) {
            final aTs = createdAtById[a.id];
            final bTs = createdAtById[b.id];
            final aDate = aTs is Timestamp ? aTs.toDate() : DateTime.now();
            final bDate = bTs is Timestamp ? bTs.toDate() : DateTime.now();
            return bDate.compareTo(aDate);
          });

          return allZaps;
        });
  }

  Future<void> deleteZap(String zapId) async {
    try {
      await _collection.doc(zapId).update({'isDeleted': true});
    } catch (e, st) {
      log('Error deleting zap', error: e, stackTrace: st);
      throw Exception('Failed to delete zap: $e');
    }
  }

  Future<void> bookmarkZap(String zapId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.bookmarksCollection)
          .doc('${userId}_$zapId')
          .set({'userId': userId, 'zapId': zapId, 'createdAt': DateTime.now()});
    } catch (e, st) {
      log('Error bookmarking zap', error: e, stackTrace: st);
      throw Exception('Failed to bookmark zap: $e');
    }
  }

  Future<void> removeBookmark(String zapId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.bookmarksCollection)
          .doc('${userId}_$zapId')
          .delete();
    } catch (e, st) {
      log('Error removing bookmark', error: e, stackTrace: st);
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
      log('Error checking bookmark', error: e, stackTrace: st);
      return false;
    }
  }

  Future<dynamic> _getUserByUsername(String username) async {
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
      log('Error getting user by username', error: e, stackTrace: st);
      return null;
    }
  }

  // --- Comments ---
  Future<void> addComment(CommentModel comment) async {
    try {
      await _firestore
          .collection('comments')
          .doc(comment.id)
          .set(comment.toMap());
    } catch (e, st) {
      log('Error adding comment', error: e, stackTrace: st);
      rethrow;
    }
  }

  Stream<List<CommentModel>> streamCommentsForPostPaginated(
    String postId,
    int limit, {
    DocumentSnapshot? startAfterDoc,
  }) {
    Query query = _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) query = query.startAfterDocument(startAfterDoc);

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map(
                (doc) => CommentModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
    );
  }

  Stream<List<CommentModel>> streamReplies(String parentCommentId) {
    return _firestore
        .collection('comments')
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  Stream<List<ZapModel>> getUserReplies(String userId) {
    if (isShort) {
      // Shorts can’t have replies — return empty stream
      return const Stream.empty();
    }

    return _zapQuery(parentOnly: false)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .where((doc) => (doc.data() as Map)['parentZapId'] != null)
                  .map(
                    (doc) =>
                        ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
                  )
                  .toList(),
        );
  }

  Future<int> getCommentsCount(String postId) async {
    try {
      final snapshot =
          await _firestore
              .collection('comments')
              .where('postId', isEqualTo: postId)
              .get();
      return snapshot.size;
    } catch (e, st) {
      log('Error getting comments count', error: e, stackTrace: st);
      return 0;
    }
  }
}
