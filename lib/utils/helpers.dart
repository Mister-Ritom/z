import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:z/models/notification_model.dart';
import 'package:z/utils/constants.dart';

class Helpers {
  /// Format number to display (e.g., 1.2K, 3.5M)
  static String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
  }

  /// Compress image file
  static Future<File?> compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Resize if too large (max 1080px on longest side)
      img.Image resized;
      if (image.width > image.height && image.width > 1080) {
        resized = img.copyResize(image, width: 1080);
      } else if (image.height > 1080) {
        resized = img.copyResize(image, height: 1080);
      } else {
        resized = image;
      }

      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      final compressedFile = File(
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Save compressed image
      await compressedFile.writeAsBytes(img.encodeJpg(resized, quality: 85));
      return compressedFile;
    } catch (e) {
      return null;
    }
  }

  /// Extract hashtags from text
  static List<String> extractHashtags(String text) {
    final regex = RegExp(r'#\w+');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Extract mentions from text
  static List<String> extractMentions(String text) {
    final regex = RegExp(r'@\w+');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate username format
  static bool isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{1,15}$').hasMatch(username);
  }

  static Future<void> createNotification({
    required String userId,
    required String fromUserId,
    required NotificationType type,
    String? tweetId,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final notification = NotificationModel(
      id: firestore.collection(AppConstants.notificationsCollection).doc().id,
      userId: userId,
      fromUserId: fromUserId,
      type: type,
      tweetId: tweetId,
      createdAt: DateTime.now(),
    );

    await firestore
        .collection(AppConstants.notificationsCollection)
        .doc(notification.id)
        .set(notification.toMap());
  }
}
