import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  Future<String> uploadProfilePicture(
    Uint8List fileBytes,
    String userId,
  ) async {
    try {
      final fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from(AppConstants.profilePicturesBucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _supabase.storage
          .from(AppConstants.profilePicturesBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  Future<String> uploadCoverPhoto(Uint8List fileBytes, String userId) async {
    try {
      final fileName =
          'cover_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from(AppConstants.coverPhotosBucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _supabase.storage
          .from(AppConstants.coverPhotosBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Failed to upload cover photo: $e');
    }
  }

  Future<String> uploadTweetImage(Uint8List fileBytes, String tweetId) async {
    try {
      final fileName =
          'tweet_${tweetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from(AppConstants.tweetMediaBucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _supabase.storage
          .from(AppConstants.tweetMediaBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Failed to upload tweet image: $e');
    }
  }

  Future<String> uploadTweetVideo(Uint8List fileBytes, String tweetId) async {
    try {
      final fileName =
          'video_${tweetId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      if (Platform.isAndroid || Platform.isIOS) {
        final tempFile = await Helpers.bytesToTempFile(fileBytes, fileName);
        final info = await VideoCompress.compressVideo(
          tempFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );
        if (info?.file == null) throw Exception("Video compression failed");

        await _supabase.storage
            .from(AppConstants.tweetMediaBucket)
            .upload(
              fileName,
              info!.file!,
              fileOptions: const FileOptions(
                contentType: 'video/mp4',
                upsert: true,
              ),
            );
        await VideoCompress.deleteAllCache();
      } else {
        await _supabase.storage
            .from(AppConstants.tweetMediaBucket)
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(
                contentType: 'video/mp4',
                upsert: true,
              ),
            );
      }

      return _supabase.storage
          .from(AppConstants.tweetMediaBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Failed to upload tweet video: $e');
    }
  }

  Future<String> uploadReel(Uint8List fileBytes, String userId) async {
    try {
      final fileName =
          'reel_${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      if (Platform.isAndroid || Platform.isIOS) {
        final tempFile = await Helpers.bytesToTempFile(fileBytes, fileName);
        final info = await VideoCompress.compressVideo(
          tempFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );
        if (info?.file == null) throw Exception("Reel compression failed");

        await _supabase.storage
            .from(AppConstants.reelsVideoBucket)
            .upload(
              fileName,
              info!.file!,
              fileOptions: const FileOptions(
                contentType: 'video/mp4',
                upsert: true,
              ),
            );
        await VideoCompress.deleteAllCache();
      } else {
        await _supabase.storage
            .from(AppConstants.reelsVideoBucket)
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(
                contentType: 'video/mp4',
                upsert: true,
              ),
            );
      }
      return _supabase.storage
          .from(AppConstants.reelsVideoBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Failed to upload reel: $e');
    }
  }

  Future<String> uploadDocument(
    Uint8List fileBytes,
    String mimeType,
    String referenceId, {
    String subFolder = "",
  }) async {
    try {
      final ext = mimeType.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'documents/subFolder$referenceId/doc_$timestamp.$ext';
      await _supabase.storage
          .from(AppConstants.documentsBucket)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
      return _supabase.storage
          .from(AppConstants.documentsBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  Future<void> deleteFile(String bucket, String fileName) async {
    try {
      await _supabase.storage.from(bucket).remove([fileName]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
