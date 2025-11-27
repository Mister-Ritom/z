import 'dart:developer';
import 'dart:typed_data';
import 'dart:io' show Platform, File;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/utils/helpers.dart';
import '../utils/constants.dart';
import 'firebase_analytics_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required UploadType type,
    required String referenceId,
  }) async {
    try {
      String bucket;
      String fileName;
      String path;
      bool isVideo = Helpers.isVideoPath(file.path);

      switch (type) {
        case UploadType.pfp:
          bucket = AppConstants.profilePicturesBucket;
          fileName =
              'profile_${referenceId}_${DateTime.now().millisecondsSinceEpoch}';
          break;
        case UploadType.cover:
          bucket = AppConstants.coverPhotosBucket;
          fileName =
              'cover_${referenceId}_${DateTime.now().millisecondsSinceEpoch}';
          break;
        case UploadType.zap:
          bucket = AppConstants.zapMediaBucket;
          fileName =
              'zap_${referenceId}_${DateTime.now().millisecondsSinceEpoch}';
          break;
        case UploadType.story:
          bucket = AppConstants.storyMediaBucket;
          fileName =
              'story_${referenceId}_${DateTime.now().millisecondsSinceEpoch}';
          break;
        case UploadType.shorts:
          bucket = AppConstants.shortsVideoBucket;
          fileName =
              'short_${referenceId}_${DateTime.now().millisecondsSinceEpoch}';
          break;
        default:
          bucket = "";
          fileName = "";
          break;
      }

      if (isVideo) {
        path = "/video";
        fileName = "$fileName.mp4";
      } else {
        path = "/image";
        fileName = "$fileName.jpg";
      }

      final ref = _storage.ref().child('$bucket$path/$fileName');
      if (isVideo && (Platform.isAndroid || Platform.isIOS)) {
        final info = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );
        if (info?.file == null) throw Exception("Video compression failed");
        await ref.putData(
          info!.file!.readAsBytesSync(),
          SettableMetadata(contentType: 'video/mp4'),
        );
        await VideoCompress.deleteAllCache();
      } else {
        final contentType =
            fileName.endsWith('.mp4') ? 'video/mp4' : 'image/jpeg';
        await ref.putData(
          file.readAsBytesSync(),
          SettableMetadata(contentType: contentType),
        );
      }

      return await ref.getDownloadURL();
    } catch (e, st) {
      log(
        "Something went wrong trying",
        error: e,
        stackTrace: st,
        name: "Storage service",
      );
      // Report error to Crashlytics
      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to upload file',
        fatal: false,
      );
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<String> uploadDocument({
    required Uint8List fileBytes,
    required String referenceId,
    required String mimeType,
    String subFolder = "",
  }) async {
    try {
      final ext = mimeType.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'documents/$subFolder/$referenceId/doc_$timestamp.$ext';
      final ref = _storage.ref().child(
        '${AppConstants.documentsBucket}/$fileName',
      );

      await ref.putData(fileBytes, SettableMetadata(contentType: mimeType));
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      // Report error to Crashlytics
      await FirebaseAnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Failed to upload document',
        fatal: false,
      );
      throw Exception('Failed to upload document: $e');
    }
  }

}
