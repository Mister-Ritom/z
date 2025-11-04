import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tweet_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class TweetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Search tweets by query (text startsWith, hashtags, or mentions)
  Future<List<TweetModel>> searchTweets(String query) async {
    try {
      final lowerQuery = query.toLowerCase();

      final tweetsRef = _firestore.collection(AppConstants.tweetsCollection);

      // Step 1: Search by hashtags
      final hashtagResults =
          await tweetsRef
              .where('hashtags', arrayContains: lowerQuery)
              .where('isDeleted', isEqualTo: false)
              .get();

      // Step 2: Search by mentions
      final mentionResults =
          await tweetsRef
              .where('mentions', arrayContains: lowerQuery)
              .where('isDeleted', isEqualTo: false)
              .get();

      // Step 3: Search by text that *starts with* query
      final textResults =
          await tweetsRef
              .where('isDeleted', isEqualTo: false)
              .orderBy('text')
              .startAt([lowerQuery])
              .endAt(['$lowerQuery\uf8ff'])
              .get();

      // Step 4: Combine all docs and remove duplicates
      final allDocs = [
        ...hashtagResults.docs,
        ...mentionResults.docs,
        ...textResults.docs,
      ];

      final uniqueDocs = {for (var doc in allDocs) doc.id: doc}.values.toList();

      // Step 5: Convert to TweetModel list
      final tweets =
          uniqueDocs
              .map((doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}))
              .toList();

      // Step 6: Sort by createdAt descending (newest first)
      tweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return tweets;
    } catch (e) {
      throw Exception('Failed to search tweets: $e');
    }
  }

  // Create a tweet
  Future<TweetModel> createTweet({
    required String userId,
    required String text,
    List<String> imageUrls = const [],
    String? videoUrl,
    String? parentTweetId,
    String? quotedTweetId,
  }) async {
    try {
      final hashtags = Helpers.extractHashtags(text);
      final mentions = Helpers.extractMentions(text);

      final tweet = TweetModel(
        id: _firestore.collection(AppConstants.tweetsCollection).doc().id,
        userId: userId,
        parentTweetId: parentTweetId,
        quotedTweetId: quotedTweetId,
        text: text,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        createdAt: DateTime.now(),
        hashtags: hashtags,
        mentions: mentions,
      );

      // Save tweet to Firestore
      await _firestore
          .collection(AppConstants.tweetsCollection)
          .doc(tweet.id)
          .set(tweet.toMap());

      // Update user's tweet count
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'tweetsCount': FieldValue.increment(1)});

      // If it's a reply, update parent tweet's reply count
      if (parentTweetId != null) {
        await _firestore
            .collection(AppConstants.tweetsCollection)
            .doc(parentTweetId)
            .update({'repliesCount': FieldValue.increment(1)});

        // Create notification
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

      // Send notifications to mentioned users
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

  // Get tweet by ID
  Future<TweetModel?> getTweetById(String tweetId) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.tweetsCollection)
              .doc(tweetId)
              .get();

      if (!doc.exists) return null;

      return TweetModel.fromMap({'id': doc.id, ...doc.data()!});
    } catch (e) {
      return null;
    }
  }

  // Get tweets feed (For You tab)
  Stream<List<TweetModel>> getForYouFeed() {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('parentTweetId', isNull: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.tweetsPerPage)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}),
                  )
                  .toList(),
        );
  }

  // Get tweets from followed users (Following tab)
  Stream<List<TweetModel>> getFollowingFeed(String userId) {
    return _firestore
        .collection(AppConstants.followingCollection)
        .doc(userId)
        .collection('users')
        .snapshots()
        .asyncMap((followingSnapshot) async {
          if (followingSnapshot.docs.isEmpty) return <TweetModel>[];

          final followingIds =
              followingSnapshot.docs.map((doc) => doc.id).toList();

          // Firestore limit for whereIn is 10, so we need to handle more than 10
          if (followingIds.length <= 10) {
            // Single query if 10 or fewer
            final tweetsQuery =
                await _firestore
                    .collection(AppConstants.tweetsCollection)
                    .where('userId', whereIn: followingIds)
                    .where('parentTweetId', isNull: true)
                    .where('isDeleted', isEqualTo: false)
                    .orderBy('createdAt', descending: true)
                    .limit(AppConstants.tweetsPerPage)
                    .get();

            return tweetsQuery.docs
                .map((doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}))
                .toList();
          } else {
            // Multiple queries for more than 10
            final List<TweetModel> allTweets = [];
            for (int i = 0; i < followingIds.length; i += 10) {
              final batch = followingIds.sublist(
                i,
                i + 10 > followingIds.length ? followingIds.length : i + 10,
              );
              final tweetsQuery =
                  await _firestore
                      .collection(AppConstants.tweetsCollection)
                      .where('userId', whereIn: batch)
                      .where('parentTweetId', isNull: true)
                      .where('isDeleted', isEqualTo: false)
                      .orderBy('createdAt', descending: true)
                      .limit(AppConstants.tweetsPerPage)
                      .get();

              allTweets.addAll(
                tweetsQuery.docs
                    .map(
                      (doc) =>
                          TweetModel.fromMap({'id': doc.id, ...doc.data()}),
                    )
                    .toList(),
              );
            }
            // Sort all tweets by createdAt and limit
            allTweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return allTweets.take(AppConstants.tweetsPerPage).toList();
          }
        });
  }

  // Get user's tweets
  Stream<List<TweetModel>> getUserTweets(String userId) {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('userId', isEqualTo: userId)
        .where('parentTweetId', isNull: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}),
                  )
                  .toList(),
        );
  }

  // Get user's replies
  Stream<List<TweetModel>> getUserReplies(String userId) {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .where((doc) => doc.data()['parentTweetId'] != null)
                  .map(
                    (doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}),
                  )
                  .toList(),
        );
  }

  // Get user's liked tweets
  Stream<List<TweetModel>> getUserLikedTweets(String userId) {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('likedBy', arrayContains: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final tweets =
              snapshot.docs
                  .map(
                    (doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}),
                  )
                  .toList();
          // Sort by createdAt descending
          tweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tweets;
        });
  }

  // Get user's retweeted tweets
  Stream<List<TweetModel>> getUserRetweetedTweets(String userId) {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('retweetedBy', arrayContains: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final tweets =
              snapshot.docs
                  .map(
                    (doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}),
                  )
                  .toList();
          // Sort by createdAt descending
          tweets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tweets;
        });
  }

  // Get tweet replies
  Stream<List<TweetModel>> getTweetReplies(String tweetId) {
    return _firestore
        .collection(AppConstants.tweetsCollection)
        .where('parentTweetId', isEqualTo: tweetId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => TweetModel.fromMap({'id': doc.id, ...doc.data()}),
                  )
                  .toList(),
        );
  }

  // Like a tweet
  Future<void> likeTweet(String tweetId, String userId) async {
    try {
      final tweetRef = _firestore
          .collection(AppConstants.tweetsCollection)
          .doc(tweetId);

      await _firestore.runTransaction((transaction) async {
        final tweetDoc = await transaction.get(tweetRef);
        if (!tweetDoc.exists) return;

        final tweet = TweetModel.fromMap({
          'id': tweetDoc.id,
          ...tweetDoc.data()!,
        });

        if (tweet.likedBy.contains(userId)) {
          // Unlike
          transaction.update(tweetRef, {
            'likesCount': FieldValue.increment(-1),
            'likedBy': FieldValue.arrayRemove([userId]),
          });
        } else {
          // Like
          transaction.update(tweetRef, {
            'likesCount': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([userId]),
          });

          // Create notification
          if (tweet.userId != userId) {
            await Helpers.createNotification(
              userId: tweet.userId,
              fromUserId: userId,
              type: NotificationType.like,
              tweetId: tweetId,
            );
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to like tweet: $e');
    }
  }

  // Retweet
  Future<void> retweet(String tweetId, String userId) async {
    try {
      final tweetRef = _firestore
          .collection(AppConstants.tweetsCollection)
          .doc(tweetId);

      await _firestore.runTransaction((transaction) async {
        final tweetDoc = await transaction.get(tweetRef);
        if (!tweetDoc.exists) return;

        final tweet = TweetModel.fromMap({
          'id': tweetDoc.id,
          ...tweetDoc.data()!,
        });

        if (tweet.retweetedBy.contains(userId)) {
          // Un-retweet
          transaction.update(tweetRef, {
            'retweetsCount': FieldValue.increment(-1),
            'retweetedBy': FieldValue.arrayRemove([userId]),
          });
        } else {
          // Retweet
          transaction.update(tweetRef, {
            'retweetsCount': FieldValue.increment(1),
            'retweetedBy': FieldValue.arrayUnion([userId]),
          });

          // Create notification
          if (tweet.userId != userId) {
            await Helpers.createNotification(
              userId: tweet.userId,
              fromUserId: userId,
              type: NotificationType.retweet,
              tweetId: tweetId,
            );
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to retweet: $e');
    }
  }

  // Delete tweet
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

  // Bookmark tweet
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

  // Remove bookmark
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

  // Helper: Get user by username
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
}
