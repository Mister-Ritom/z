import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/supabase/database.dart';
import 'package:z/utils/logger.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/utils/constants.dart';
import '../analytics/firebase_analytics_service.dart';

class StorageService {
  final SupabaseClient _supabase = Database.client;

  static const _maxRetries = 3;
  static const _timeout = Duration(seconds: 60);

  Future<String> uploadFile({
    required File file,
    required UploadType type,
    required String referenceId,
    bool private = false,
    int privatUrlDurationSeconds = 60 * 60 * 24 * 365,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        final isVideo = Helpers.isVideoPath(file.path);

        final bucket = _getBucket(type);
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final ext = isVideo ? 'mp4' : 'jpg';
        final folder = isVideo ? 'video' : 'image';
        final fileName = "${type.name}_${referenceId}_$timestamp.$ext";
        final storagePath = "$folder/$fileName";

        File uploadFile = file;

        if (isVideo) {
          final info = await VideoCompress.compressVideo(
            file.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
          );
          if (info?.file != null) uploadFile = info!.file!;
        }

        final mime =
            lookupMimeType(uploadFile.path) ??
            (isVideo ? 'video/mp4' : 'image/jpeg');

        await _supabase.storage
            .from(bucket)
            .upload(
              storagePath,
              uploadFile,
              fileOptions: FileOptions(contentType: mime, upsert: false),
            )
            .timeout(_timeout);

        if (isVideo) {
          await VideoCompress.deleteAllCache();
        }

        final url =
            private
                ? await _supabase.storage
                    .from(bucket)
                    .createSignedUrl(storagePath, privatUrlDurationSeconds)
                : _supabase.storage.from(bucket).getPublicUrl(storagePath);

        AppLogger.info(
          'StorageService',
          'Upload success',
          data: {'bucket': bucket, 'path': storagePath},
        );

        return url;
      } catch (e, st) {
        attempt++;

        AppLogger.error(
          'StorageService',
          'Upload failed attempt $attempt',
          error: e,
          stackTrace: st,
        );

        if (attempt >= _maxRetries) {
          await FirebaseAnalyticsService.recordError(
            e,
            st,
            reason: 'Supabase upload failed',
            fatal: false,
          );
          throw Exception('Upload failed after retries: $e');
        }

        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  Future<String> uploadDocument({
    required Uint8List fileBytes,
    required String referenceId,
    required String mimeType,
    String subFolder = "",
    bool private = false,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        final bucket = AppConstants.documentsBucket;
        final ext = mimeType.split('/').last;
        final timestamp = DateTime.now().microsecondsSinceEpoch;

        final path = "documents/$subFolder/$referenceId/doc_$timestamp.$ext";

        await _supabase.storage
            .from(bucket)
            .uploadBinary(
              path,
              fileBytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: false),
            )
            .timeout(_timeout);

        final url =
            private
                ? await _supabase.storage
                    .from(bucket)
                    .createSignedUrl(path, 60 * 60 * 24 * 365)
                : _supabase.storage.from(bucket).getPublicUrl(path);

        AppLogger.info(
          'StorageService',
          'Document upload success',
          data: {'bucket': bucket, 'path': path},
        );

        return url;
      } catch (e, st) {
        attempt++;

        AppLogger.error(
          'StorageService',
          'Document upload failed attempt $attempt',
          error: e,
          stackTrace: st,
        );

        if (attempt >= _maxRetries) {
          await FirebaseAnalyticsService.recordError(
            e,
            st,
            reason: 'Supabase document upload failed',
            fatal: false,
          );
          throw Exception('Document upload failed after retries: $e');
        }

        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  String _getBucket(UploadType type) {
    switch (type) {
      case UploadType.pfp:
        return AppConstants.profilePicturesBucket;
      case UploadType.cover:
        return AppConstants.coverPhotosBucket;
      case UploadType.zap:
        return AppConstants.zapMediaBucket;
      case UploadType.story:
        return AppConstants.storyMediaBucket;
      case UploadType.shorts:
        return AppConstants.shortsVideoBucket;
      default:
        throw Exception("Invalid upload type");
    }
  }
}
