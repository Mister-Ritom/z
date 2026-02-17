import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:z/utils/logger.dart';
import '../services/storage/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final uploadNotifierProvider =
    StateNotifierProvider<UploadNotifier, List<UploadTaskState>>(
      (ref) => UploadNotifier(ref),
    );

enum UploadType { zap, shorts, cover, pfp, story, document }

class UploadTaskState {
  final String id;
  final String fileName;
  final double progress;
  final UploadType type;
  final bool isUploading;
  final String? downloadUrl;
  final String? error;

  const UploadTaskState({
    required this.id,
    required this.fileName,
    required this.progress,
    required this.type,
    this.isUploading = false,
    this.downloadUrl,
    this.error,
  });

  UploadTaskState copyWith({
    double? progress,
    bool? isUploading,
    String? downloadUrl,
    String? error,
  }) {
    return UploadTaskState(
      id: id,
      fileName: fileName,
      progress: progress ?? this.progress,
      type: type,
      isUploading: isUploading ?? this.isUploading,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      error: error ?? this.error,
    );
  }
}

class UploadNotifier extends StateNotifier<List<UploadTaskState>> {
  final Ref ref;
  UploadNotifier(this.ref) : super([]);

  static const _parallelLimit = 3;
  static const _maxRetries = 2;

  Future<void> uploadFiles({
    required List<XFile> files,
    required UploadType type,
    required String referenceId,
    void Function(List<String> urls)? onComplete,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final uploadedUrls = <String>[];
    final queue = <Future<void>>[];

    for (int i = 0; i < files.length; i++) {
      if (queue.length >= _parallelLimit) {
        await Future.any(queue);
        for (final f in queue) {
          f.whenComplete(() => queue.remove(f));
        }
      }

      final file = files[i];
      final id = const Uuid().v4();

      state = [
        ...state,
        UploadTaskState(
          id: id,
          fileName: file.name,
          progress: 0,
          type: type,
          isUploading: true,
        ),
      ];

      queue.add(
        _uploadSingle(
          id: id,
          file: file,
          index: i,
          type: type,
          referenceId: referenceId,
          storage: storage,
          onDone: (url) => uploadedUrls.add(url),
        ),
      );
    }

    await Future.wait(queue);
    if (onComplete != null) onComplete(uploadedUrls);
  }

  Future<void> _uploadSingle({
    required String id,
    required XFile file,
    required int index,
    required UploadType type,
    required String referenceId,
    required StorageService storage,
    required void Function(String url) onDone,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        final mime = file.mimeType ?? lookupMimeType(file.path) ?? '';
        String downloadUrl = "";

        _setProgress(id, 0.1);

        switch (type) {
          case UploadType.zap:
          case UploadType.story:
            if (mime.startsWith('image/') || mime.startsWith('video/')) {
              final refId = "$referenceId-$index";
              downloadUrl = await storage.uploadFile(
                file: File(file.path),
                type: type,
                referenceId: refId,
              );
            } else {
              final bytes = await file.readAsBytes();
              downloadUrl = await storage.uploadDocument(
                fileBytes: bytes,
                mimeType: mime,
                referenceId: referenceId,
              );
            }
            break;

          case UploadType.shorts:
            if (!mime.startsWith('video/')) {
              throw Exception("Shorts must be video");
            }
            downloadUrl = await storage.uploadFile(
              file: File(file.path),
              type: type,
              referenceId: referenceId,
            );
            break;

          case UploadType.cover:
          case UploadType.pfp:
            if (!mime.startsWith('image/')) {
              throw Exception("Image required");
            }
            downloadUrl = await storage.uploadFile(
              file: File(file.path),
              type: type,
              referenceId: referenceId,
            );
            break;

          case UploadType.document:
            final bytes = await file.readAsBytes();
            downloadUrl = await storage.uploadDocument(
              fileBytes: bytes,
              mimeType: mime,
              referenceId: referenceId,
            );
            break;
        }

        _setProgress(id, 1.0, done: true, url: downloadUrl);
        onDone(downloadUrl);

        await Future.delayed(const Duration(seconds: 2));
        _remove(id);
        return;
      } catch (e, st) {
        attempt++;
        AppLogger.error(
          'UploadNotifier',
          'Upload failed',
          error: e,
          stackTrace: st,
          data: {'file': file.path},
        );

        if (attempt > _maxRetries) {
          _setError(id, e.toString());
          return;
        }

        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  void _setProgress(
    String id,
    double progress, {
    bool done = false,
    String? url,
  }) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(
            progress: progress,
            isUploading: !done,
            downloadUrl: url ?? t.downloadUrl,
          )
        else
          t,
    ];
  }

  void _setError(String id, String err) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(isUploading: false, error: err) else t,
    ];
  }

  void _remove(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}
