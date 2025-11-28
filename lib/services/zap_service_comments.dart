part of 'zap_service.dart';

mixin _ZapServiceComments on _ZapServiceBase {
  Future<void> addComment(CommentModel comment) async {
    try {
      await _firestore
          .collection('comments')
          .doc(comment.id)
          .set(comment.toMap());
      AppLogger.info(
        'ZapService',
        'Comment added successfully',
        data: {'commentId': comment.id, 'postId': comment.postId},
      );
    } catch (e, st) {
      AppLogger.error(
        'ZapService',
        'Error adding comment',
        error: e,
        stackTrace: st,
        data: {'commentId': comment.id, 'postId': comment.postId},
      );
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
}
