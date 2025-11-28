part of 'zap_service.dart';

mixin _ZapServiceStreams on _ZapServiceBase {
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
      AppLogger.error(
        'ZapService',
        'Error getting for-you feed',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort},
      );
      unawaited(
        FirebaseAnalyticsService.recordError(
          e,
          st,
          reason: 'Failed to get for-you feed',
          fatal: false,
        ),
      );
      rethrow;
    }
  }

  Stream<List<ZapModel>> getFollowingFeed(String userId) {
    return _firestore
        .collection(AppConstants.followingCollection)
        .doc(userId)
        .collection('users')
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) return <ZapModel>[];

          final followingIds = snapshot.docs.map((doc) => doc.id).toList();
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

  Stream<List<ZapModel>> getUserReplies(String userId) {
    if (isShort) {
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
}
