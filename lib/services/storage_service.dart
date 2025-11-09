import 'dart:typed_data';
import 'dart:io' show Platform, File;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';
import 'package:z/providers/storage_provider.dart';
import '../utils/constants.dart';

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
      String path = "/image";
      bool isVideo = false;

      switch (type) {
        case UploadType.pfp:
          bucket = AppConstants.profilePicturesBucket;
          fileName =
              'profile_${referenceId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          break;
        case UploadType.cover:
          bucket = AppConstants.coverPhotosBucket;
          fileName =
              'cover_${referenceId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          break;
        case UploadType.tweet:
          bucket = AppConstants.tweetMediaBucket;
          fileName =
              'tweet_${referenceId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          break;
        case UploadType.story:
          bucket = AppConstants.storyMediaBucket;
          fileName =
              'story_${referenceId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          break;
        case UploadType.reels:
          bucket = AppConstants.reelsVideoBucket;
          fileName =
              'reel_${referenceId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
          isVideo = true;
          break;
        default:
          bucket = "";
          fileName = "";
          break;
      }

      final ref = _storage.ref().child('$bucket$path/$fileName');
      if (isVideo) path = "/video";
      if (isVideo && (Platform.isAndroid || Platform.isIOS)) {
        final info = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );
        if (info?.file == null) throw Exception("Video compression failed");
        await ref.putFile(
          info!.file!,
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
    } catch (e) {
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
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  Future<void> deleteFile(String bucket, String fileName) async {
    try {
      final ref = _storage.ref().child('$bucket/$fileName');
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
