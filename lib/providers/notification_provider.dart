import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';

final notificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) {
      return FirebaseFirestore.instance
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .where('type', isNotEqualTo: 'message')
          .limit(50)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => NotificationModel.fromMap({
                        'id': doc.id,
                        ...doc.data(),
                      }),
                    )
                    .toList(),
          );
    });

final unreadNotificationsCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return FirebaseFirestore.instance
      .collection(AppConstants.notificationsCollection)
      .where('userId', isEqualTo: userId)
      .where('isRead', isEqualTo: false)
      .where("type", isNotEqualTo: "message")
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

Future<void> markAllNotificationsAsRead(String userId) async {
  final querySnapshot =
      await FirebaseFirestore.instance
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .where('type', isNotEqualTo: 'message')
          .get();

  final batch = FirebaseFirestore.instance.batch();

  for (var doc in querySnapshot.docs) {
    batch.update(doc.reference, {'isRead': true});
  }

  await batch.commit();
}
