import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:z/models/comment_model.dart';
import '../models/tweet_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class TweetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Query _tweetQuery({bool? isReel, bool parentOnly = true}) {
    Query query = _firestore
        .collection(AppConstants.tweetsCollection)
        .where('isDeleted', isEqualTo: false);

    if (isReel != null) query = query.where('isReel', isEqualTo: isReel);
    if (parentOnly) query = query.where('parentTweetId', isNull: true);

    return query;
  }

  Future<List<TweetModel>> searchTweets(String query, {bool? isReel}) async {
    try {
      final lowerQuery = query.toLowerCase();
      final tweetsRef = _firestore.collection(AppConstants.tweetsCollection);

      final hashtagResults =
          await tweetsRef
              .where('hashtags', arrayContains: lowerQuery)
              .where('isDeleted', isEqualTo: false)
              .where('isReel', isEqualTo: isReel ?? false)
              .get();

      final mentionResults =
          await tweetsRef
              .where('mentions', arrayContains: lowerQuery)
              .where('isDeleted', isEqualTo: false)
              .where('isReel', isEqualTo: isReel ?? false)
              .get();

      final textResults =
          await tweetsRef
              .where('isDeleted', isEqualTo: false)
              .where('isReel', isEqualTo: isReel ?? false)
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

      final tweets =
          uniqueDocs
              .map((doc) {
                if (doc.exists) {
                  return TweetModel.fromMap({
                    'id': doc.id,
                    ...doc.data() as Map,
                  });
                }
                return null;
              })
              .whereType<TweetModel>()
              .toList();

      tweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tweets;
    } catch (e) {
      throw Exception('Failed to search tweets: $e');
    }
  }

  Future<TweetModel> createTweet({
    required String tweetId,
    required String userId,
    required String text,
    List<String> mediaUrls = const [],
    String? parentTweetId,
    String? quotedTweetId,
    bool isReel = false,
  }) async {
    try {
      final hashtags = Helpers.extractHashtags(text);
      final mentions = Helpers.extractMentions(text);

      final tweet = TweetModel(
        id: tweetId,
        userId: userId,
        parentTweetId: parentTweetId,
        quotedTweetId: quotedTweetId,
        text: text,
        mediaUrls: mediaUrls,
        createdAt: DateTime.now(),
        hashtags: hashtags,
        mentions: mentions,
        isReel: isReel,
      );

      await _firestore
          .collection(
            isReel
                ? AppConstants.shortsCollection
                : AppConstants.tweetsCollection,
          )
          .doc(tweet.id)
          .set(tweet.toMap());

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'tweetsCount': FieldValue.increment(1)});

      if (parentTweetId != null) {
        await _firestore
            .collection(AppConstants.tweetsCollection)
            .doc(parentTweetId)
            .update({'repliesCount': FieldValue.increment(1)});

        final parentTweet = await getTweetById(parentTweetId);
        if (parentTweet != null && parentTweet.userId != userId) {
          await Helpers.createNotification(
            userId: parentTweet.userId,
            fromUserId: userId,
            type: NotificationType.reply,
            tweetId: tweet.id,
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
            tweetId: tweet.id,
          );
        }
      }

      return tweet;
    } catch (e) {
      throw Exception('Failed to create tweet: $e');
    }
  }

  Future<TweetModel?> getTweetById(String tweetId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.tweetsCollection)
              .doc(tweetId)
              .get();

      if (!doc.exists || doc.data() == null) return null;

      return TweetModel.fromMap({'id': doc.id, ...doc.data() as Map});
    } catch (e) {
      return null;
    }
  }

  Stream<List<TweetModel>> getForYouFeed({
    DocumentSnapshot? lastDoc,
    required bool isReel,
  }) {
    Query query = _tweetQuery(
      isReel: isReel,
    ).orderBy('createdAt', descending: true).limit(AppConstants.tweetsPerPage);

    if (lastDoc != null) query = query.startAfterDocument(lastDoc);
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) {
                if (doc.exists && doc.data() != null) {
                  return TweetModel.fromMap({
                    'id': doc.id,
                    ...doc.data() as Map,
                  }, snapshot: doc);
                }
                return null;
              })
              .whereType<TweetModel>()
              .toList(),
    );
  }

  Stream<List<TweetModel>> getFollowingFeed(String userId, {bool? isReel}) {
    return _firestore
        .collection(AppConstants.followingCollection)
        .doc(userId)
        .collection('users')
        .snapshots()
        .asyncMap((followingSnapshot) async {
          if (followingSnapshot.docs.isEmpty) return <TweetModel>[];

          final followingIds =
              followingSnapshot.docs.map((doc) => doc.id).toList();
          final List<TweetModel> allTweets = [];

          for (int i = 0; i < followingIds.length; i += 10) {
            final batch = followingIds.sublist(
              i,
              i + 10 > followingIds.length ? followingIds.length : i + 10,
            );
            final tweetsQuery =
                await _tweetQuery(isReel: isReel)
                    .where('userId', whereIn: batch)
                    .orderBy('createdAt', descending: true)
                    .limit(AppConstants.tweetsPerPage)
                    .get();

            allTweets.addAll(
              tweetsQuery.docs
                  .map((doc) {
                    if (doc.exists && doc.data() != null) {
                      return TweetModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<TweetModel>()
                  .toList(),
            );
          }

          allTweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return allTweets.take(AppConstants.tweetsPerPage).toList();
        });
  }

  Stream<List<TweetModel>> getUserTweets(String userId, {bool? isReel}) {
    return _tweetQuery(isReel: isReel)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) {
                    if (doc.exists && doc.data() != null) {
                      return TweetModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<TweetModel>()
                  .toList(),
        );
  }

  Stream<List<TweetModel>> getUserReplies(String userId, {bool? isReel}) {
    return _tweetQuery(isReel: isReel, parentOnly: false)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .where((doc) => (doc.data() as Map)['parentTweetId'] != null)
                  .map((doc) {
                    if (doc.exists && doc.data() != null) {
                      return TweetModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<TweetModel>()
                  .toList(),
        );
  }

  Stream<List<TweetModel>> getUserLikedTweets(String userId) {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('likedBy', arrayContains: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final tweets =
              snapshot.docs
                  .map((doc) {
                    if (doc.exists) {
                      return TweetModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<TweetModel>()
                  .toList();
          tweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tweets;
        });
  }

  Stream<List<TweetModel>> getUserRetweetedTweets(String userId) {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('retweetedBy', arrayContains: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final tweets =
              snapshot.docs
                  .map((doc) {
                    if (doc.exists) {
                      return TweetModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<TweetModel>()
                  .toList();
          tweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tweets;
        });
  }

  Stream<List<TweetModel>> getTweetReplies(String tweetId, {bool? isReel}) {
    return _tweetQuery(isReel: isReel, parentOnly: false)
        .where('parentTweetId', isEqualTo: tweetId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) {
                    if (doc.exists && doc.data() != null) {
                      return TweetModel.fromMap({
                        'id': doc.id,
                        ...doc.data() as Map,
                      });
                    }
                    return null;
                  })
                  .whereType<TweetModel>()
                  .toList(),
        );
  }

  Stream<List<TweetModel>> getUserBookmarkedTweets(String userId) {
    return _firestore
        .collection(AppConstants.bookmarksCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return <TweetModel>[];

          final tweetIds =
              snapshot.docs
                  .map((d) => (d.data() as Map)['tweetId'] as String)
                  .toList();

          final List<TweetModel> allTweets = [];
          for (int i = 0; i < tweetIds.length; i += 10) {
            final batch = tweetIds.sublist(
              i,
              i + 10 > tweetIds.length ? tweetIds.length : i + 10,
            );
            final tweetsQuery =
                await _firestore
                    .collection(AppConstants.tweetsCollection)
                    .where('isDeleted', isEqualTo: false)
                    .where(FieldPath.documentId, whereIn: batch)
                    .get();

            allTweets.addAll(
              tweetsQuery.docs
                  .map(
                    (doc) => TweetModel.fromMap({
                      'id': doc.id,
                      ...doc.data() as Map,
                    }),
                  )
                  .toList(),
            );
          }

          // Sort by bookmark createdAt order from snapshot
          final createdAtById = {
            for (final d in snapshot.docs)
              (d.data() as Map)['tweetId'] as String:
                  (d.data() as Map)['createdAt'],
          };
          allTweets.sort((a, b) {
            final aTs = createdAtById[a.id];
            final bTs = createdAtById[b.id];
            final aDate = aTs is Timestamp ? aTs.toDate() : DateTime.now();
            final bDate = bTs is Timestamp ? bTs.toDate() : DateTime.now();
            return bDate.compareTo(aDate);
          });

          return allTweets;
        });
  }

  Future<void> deleteTweet(String tweetId) async {
    try {
      await _firestore
          .collection(AppConstants.tweetsCollection)
          .doc(tweetId)
          .update({'isDeleted': true});
    } catch (e) {
      throw Exception('Failed to delete tweet: $e');
    }
  }

  Future<void> bookmarkTweet(String tweetId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.bookmarksCollection)
          .doc('${userId}_$tweetId')
          .set({
            'userId': userId,
            'tweetId': tweetId,
            'createdAt': DateTime.now(),
          });
    } catch (e) {
      throw Exception('Failed to bookmark tweet: $e');
    }
  }

  Future<void> removeBookmark(String tweetId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.bookmarksCollection)
          .doc('${userId}_$tweetId')
          .delete();
    } catch (e) {
      throw Exception('Failed to remove bookmark: $e');
    }
  }

  Future<bool> isBookmarked(String tweetId, String userId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.bookmarksCollection)
              .doc('${userId}_$tweetId')
              .get();

      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check bookmark: $e');
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
    } catch (e) {
      return null;
    }
  }

  // Add a comment
  Future<void> addComment(CommentModel comment) async {
    await _firestore
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());
  }

  // Paginated stream of comments for a specific post
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

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

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

  // Stream replies to a specific comment
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

  // Get number of comments for a post
  Future<int> getCommentsCount(String postId) async {
    final snapshot =
        await _firestore
            .collection('comments')
            .where('postId', isEqualTo: postId)
            .get();
    return snapshot.size;
  }
}
