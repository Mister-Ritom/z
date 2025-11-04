import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  try {
    return Supabase.instance.client;
  } catch (e) {
    throw Exception('Supabase not initialized. Initialize in main.dart first.');
  }
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return StorageService(supabase);
});

final uploadNotifierProvider =
    StateNotifierProvider<UploadNotifier, List<UploadTaskState>>(
      (ref) => UploadNotifier(ref),
    );

enum UploadType { tweet, reels, cover, pfp, document }

class UploadTaskState {
  final String fileName;
  final double progress;
  final UploadType type;
  final bool isUploading;
  final String? downloadUrl;
  final String? error;

  const UploadTaskState({
    required this.fileName,
    required this.progress,
    required this.type,
    this.isUploading = false,
    this.downloadUrl,
    this.error,
  });

  UploadTaskState copyWith({
    String? fileName,
    double? progress,
    UploadType? type,
    bool? isUploading,
    String? downloadUrl,
    String? error,
  }) {
    return UploadTaskState(
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      type: type ?? this.type,
      isUploading: isUploading ?? this.isUploading,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      error: error ?? this.error,
    );
  }
}

class UploadNotifier extends StateNotifier<List<UploadTaskState>> {
  final Ref ref;
  UploadNotifier(this.ref) : super([]);

  Future<void> uploadFiles({
    required List<XFile> files,
    required UploadType type,
    required String referenceId,
    void Function(List<String> urls)? onComplete,
  }) async {
    final storage = ref.read(storageServiceProvider);

    final newTasks =
        files
            .map(
              (_) => UploadTaskState(
                fileName: const Uuid().v4(),
                type: type,
                progress: 0,
                isUploading: true,
              ),
            )
            .toList();

    state = [...state, ...newTasks];

    final uploadedUrls = <String>[];
    final tasks = <Future<void>>[];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final taskIndex = state.length - files.length + i;
      final taskId = state[taskIndex].fileName;

      tasks.add(
        Future(() async {
          try {
            final mimeType = file.mimeType ?? getMimeTypeFromPath(file.path);
            final fileBytes = await file.readAsBytes();
            String downloadUrl = "";

            log("📤 Uploading: ${file.name} [$mimeType] as $type");

            Future<void> updateProgress(double p) async {
              state = [
                for (int j = 0; j < state.length; j++)
                  if (j == taskIndex)
                    state[j].copyWith(progress: p, isUploading: true)
                  else
                    state[j],
              ];
            }

            await updateProgress(0.2);

            switch (type) {
              case UploadType.tweet:
                if (mimeType.startsWith('image/')) {
                  downloadUrl = await storage.uploadTweetImage(
                    fileBytes,
                    '$referenceId-img-$i',
                  );
                } else if (mimeType.startsWith('video/')) {
                  downloadUrl = await storage.uploadTweetVideo(
                    fileBytes,
                    '$referenceId-vid-$i',
                  );
                } else {
                  downloadUrl = await storage.uploadDocument(
                    fileBytes,
                    mimeType,
                    referenceId,
                  );
                }
                break;

              case UploadType.reels:
                if (!mimeType.startsWith('video/')) {
                  throw Exception("❌ Reels can only contain video files.");
                }
                downloadUrl = await storage.uploadReel(fileBytes, referenceId);
                break;

              case UploadType.cover:
                if (!mimeType.startsWith('image/')) {
                  throw Exception("❌ Cover photo must be an image.");
                }
                downloadUrl = await storage.uploadCoverPhoto(
                  fileBytes,
                  referenceId,
                );
                break;

              case UploadType.pfp:
                if (!mimeType.startsWith('image/')) {
                  throw Exception("❌ Profile picture must be an image.");
                }
                downloadUrl = await storage.uploadProfilePicture(
                  fileBytes,
                  referenceId,
                );
                break;

              case UploadType.document:
                downloadUrl = await storage.uploadDocument(
                  fileBytes,
                  mimeType,
                  referenceId,
                );
                break;
            }

            await updateProgress(1.0);
            uploadedUrls.add(downloadUrl);

            state = [
              for (int j = 0; j < state.length; j++)
                if (j == taskIndex)
                  state[j].copyWith(
                    progress: 1.0,
                    isUploading: false,
                    downloadUrl: downloadUrl,
                  )
                else
                  state[j],
            ];

            await Future.delayed(const Duration(seconds: 2));
            state = state.where((t) => t.fileName != taskId).toList();
          } catch (e, st) {
            log("❌ Upload failed for ${file.path}", error: e, stackTrace: st);
            state = [
              for (int j = 0; j < state.length; j++)
                if (j == taskIndex)
                  state[j].copyWith(isUploading: false, error: e.toString())
                else
                  state[j],
            ];
          }
        }),
      );
    }

    for (final task in tasks) {
      await task;
    }

    log("✅ All uploads done. URLs:\n${uploadedUrls.join("\n")}");
    if (onComplete != null) onComplete(uploadedUrls);
  }

  String getMimeTypeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return 'audio/mpeg';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }
}
