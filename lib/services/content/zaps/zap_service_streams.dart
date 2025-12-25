part of 'zap_service.dart';

mixin _ZapServiceStreams on _ZapServiceBase {
  Stream<List<ZapModel>> getForYouFeed({DocumentSnapshot? lastDoc}) {
    try {
      Query query = _zapQuery()
          .orderBy('createdAt', descending: true)
          .limit(AppConstants.zapsPerPage);

      if (lastDoc != null) query = query.startAfterDocument(lastDoc);

      return query.snapshots().map(
        (snapshot) => FirestoreUtils.parseDocumentsSafely<ZapModel>(
          docs: snapshot.docs,
          parser:
              (doc) => ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
          serviceName: 'ZapService',
        ),
      );
    } catch (e, st) {
      unawaited(
        FirestoreUtils.handleError(
          serviceName: 'ZapService',
          operation: 'Error getting for-you feed',
          error: e,
          stackTrace: st,
          data: {'isShort': isShort},
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

          // Fetch in batches (whereIn supports max 10)
          for (
            int i = 0;
            i < followingIds.length;
            i += FirestoreUtils.maxBatchSize
          ) {
            final batch = followingIds.sublist(
              i,
              i + FirestoreUtils.maxBatchSize > followingIds.length
                  ? followingIds.length
                  : i + FirestoreUtils.maxBatchSize,
            );

            final zapsQuery =
                await _zapQuery()
                    .where('userId', whereIn: batch)
                    .orderBy('createdAt', descending: true)
                    .limit(AppConstants.zapsPerPage)
                    .get();

            allZaps.addAll(
              FirestoreUtils.parseDocumentsSafely<ZapModel>(
                docs: zapsQuery.docs,
                parser:
                    (doc) =>
                        ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
                serviceName: 'ZapService',
              ),
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
          (snapshot) => FirestoreUtils.parseDocumentsSafely<ZapModel>(
            docs: snapshot.docs,
            parser:
                (doc) => ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
            serviceName: 'ZapService',
          ),
        );
  }

  Stream<List<ZapModel>> getZapReplies(String zapId) {
    if (isShort) return const Stream.empty();
    return _zapQuery(parentOnly: false)
        .where('parentZapId', isEqualTo: zapId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => FirestoreUtils.parseDocumentsSafely<ZapModel>(
            docs: snapshot.docs,
            parser:
                (doc) => ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
            serviceName: 'ZapService',
          ),
        );
  }

  Stream<List<ZapModel>> getUserLikedZaps(String userId) {
    return _collection
        .where('likedBy', arrayContains: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final zaps = FirestoreUtils.parseDocumentsSafely<ZapModel>(
            docs: snapshot.docs,
            parser:
                (doc) => ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
            serviceName: 'ZapService',
          );
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
          final zaps = FirestoreUtils.parseDocumentsSafely<ZapModel>(
            docs: snapshot.docs,
            parser:
                (doc) => ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
            serviceName: 'ZapService',
          );
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

          final allZaps = await FirestoreUtils.fetchDocumentsByIds<ZapModel>(
            collection: _collection,
            ids: zapIds,
            parser:
                (doc) => ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
            filter: (data) => data['isDeleted'] != true,
          );

          // Sort by bookmark creation time (not zap creation time)
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
          (snapshot) => FirestoreUtils.parseDocumentsSafely<ZapModel>(
            docs:
                snapshot.docs
                    .where((doc) => (doc.data() as Map)['parentZapId'] != null)
                    .toList(),
            parser:
                (doc) => ZapModel.fromMap({'id': doc.id, ...doc.data() as Map}),
            serviceName: 'ZapService',
          ),
        );
  }
}
