import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  // Upload profile picture
  Future<String> uploadProfilePicture(File imageFile, String userId) async {
    try {
      // Compress image
      final compressedFile = await Helpers.compressImage(imageFile);
      final fileToUpload = compressedFile ?? imageFile;

      final fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await fileToUpload.readAsBytes();

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

      // Get public URL
      final url = _supabase.storage
          .from(AppConstants.profilePicturesBucket)
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Upload cover photo
  Future<String> uploadCoverPhoto(File imageFile, String userId) async {
    try {
      // Compress image
      final compressedFile = await Helpers.compressImage(imageFile);
      final fileToUpload = compressedFile ?? imageFile;

      final fileName =
          'cover_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await fileToUpload.readAsBytes();

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

      // Get public URL
      final url = _supabase.storage
          .from(AppConstants.coverPhotosBucket)
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      throw Exception('Failed to upload cover photo: $e');
    }
  }

  // Upload tweet image
  Future<String> uploadTweetImage(File imageFile, String tweetId) async {
    try {
      // Compress image
      final compressedFile = await Helpers.compressImage(imageFile);
      final fileToUpload = compressedFile ?? imageFile;

      final fileName =
          'tweet_${tweetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await fileToUpload.readAsBytes();

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

      // Get public URL
      final url = _supabase.storage
          .from(AppConstants.tweetMediaBucket)
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      throw Exception('Failed to upload tweet image: $e');
    }
  }

  Future<String> uploadTweetVideo(File videoFile, String tweetId) async {
    try {
      // 1️⃣ Compress the video before upload
      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality, // balance speed & quality
        deleteOrigin: false,
      );

      if (info == null || info.file == null) {
        throw Exception('Video compression failed');
      }

      final compressedFile = info.file!;
      final fileName =
          'video_${tweetId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // 2️⃣ Upload the file directly (streaming, faster & memory-efficient)
      await _supabase.storage
          .from(AppConstants.tweetMediaBucket)
          .upload(
            fileName,
            compressedFile,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          );

      // 3️⃣ Clean up temporary cache files
      await VideoCompress.deleteAllCache();

      // 4️⃣ Get the public URL of the uploaded file
      final url = _supabase.storage
          .from(AppConstants.tweetMediaBucket)
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      throw Exception('Failed to upload tweet video: $e');
    }
  }

  // Upload multiple tweet images
  Future<List<String>> uploadTweetImages(
    List<File> imageFiles,
    String tweetId,
  ) async {
    try {
      final urls = <String>[];

      for (var i = 0; i < imageFiles.length; i++) {
        final url = await uploadTweetImage(imageFiles[i], '$tweetId$i');
        urls.add(url);
      }

      return urls;
    } catch (e) {
      throw Exception('Failed to upload tweet images: $e');
    }
  }

  // Delete file from storage
  Future<void> deleteFile(String bucket, String fileName) async {
    try {
      await _supabase.storage.from(bucket).remove([fileName]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
