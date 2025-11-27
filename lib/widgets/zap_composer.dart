import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/profile_picture.dart';
import 'package:z/widgets/video_player_widget.dart';
import '../providers/zap_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/storage_provider.dart';
import '../services/firebase_analytics_service.dart';
import '../utils/constants.dart';

class ZapComposer extends ConsumerStatefulWidget {
  final String? replyToZapId;
  final VoidCallback? onZapSent;

  const ZapComposer({super.key, this.replyToZapId, this.onZapSent});

  @override
  ConsumerState<ZapComposer> createState() => _ZapComposerState();
}

class _ZapComposerState extends ConsumerState<ZapComposer> {
  final _textController = TextEditingController();
  final selectedMediaProvider = StateProvider<List<XFile>>((ref) => []);
  final remainingCharsProvider = StateProvider(
    (ref) => AppConstants.maxZapLength,
  );
  final isShortProvider = StateProvider((ref) => false);

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final len = _textController.text.length;
      final newRemaining = AppConstants.maxZapLength - len;
      final remainingChars = ref.watch(remainingCharsProvider);
      if (remainingChars != newRemaining) {
        ref.read(remainingCharsProvider.notifier).state = newRemaining;
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final isShort = ref.read(isShortProvider);

    if (isShort) {
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      ref.read(selectedMediaProvider.notifier).state = [video];
    } else {
      final media = await picker.pickMultipleMedia();
      if (media.isEmpty) return;

      final currentMedia = ref.read(selectedMediaProvider);
      final total = currentMedia.length + media.length;
      if (total > AppConstants.maxImagesPerZap) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Maximum ${AppConstants.maxImagesPerZap} media files allowed',
              ),
            ),
          );
        }
        return;
      }

      ref.read(selectedMediaProvider.notifier).state = [
        ...currentMedia,
        ...media,
      ];
    }
  }

  Future<void> _addSong() async {
    // TODO: Implement song picker for shorts
  }

  Future<void> _sendZap(String currentUserId) async {
    final text = _textController.text.trim();
    final media = ref.read(selectedMediaProvider);
    final isShort = ref.read(isShortProvider);

    if (text.isEmpty && media.isEmpty) {
      if (isShort && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A short must have a video')),
        );
      }
      return;
    }

    if (text.length > AppConstants.maxZapLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text exceeds character limit')),
        );
      }
      return;
    }

    final id =
        FirebaseFirestore.instance
            .collection(AppConstants.zapsCollection)
            .doc()
            .id;
    final zapService = ref.read(zapServiceProvider(isShort));
    final uploadService = ref.read(uploadNotifierProvider.notifier);

    try {
      if (media.isNotEmpty) {
        uploadService.uploadFiles(
          files: media,
          type: isShort ? UploadType.shorts : UploadType.zap,
          referenceId: id,
          onComplete: (urls) async {
            await zapService.createZap(
              zapId: id,
              userId: currentUserId,
              text: text,
              mediaUrls: urls,
              parentZapId: widget.replyToZapId,
            );
            // Track post creation
            await FirebaseAnalyticsService.logPostCreated(
              contentType: 'media',
              isShort: isShort,
            );
          },
        );
      } else if (isShort && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A short must have a video')),
        );
        return;
      } else {
        await zapService.createZap(
          zapId: id,
          userId: currentUserId,
          text: text,
          parentZapId: widget.replyToZapId,
        );
        // Track post creation
        await FirebaseAnalyticsService.logPostCreated(
          contentType: 'text',
          isShort: isShort,
        );
      }
    } catch (e, st) {
      log('Failed async zap upload', error: e, stackTrace: st);
      // Report error to Crashlytics
      await FirebaseAnalyticsService.recordError(
        e,
        st,
        reason: 'Failed to create zap/short',
        fatal: false,
      );
    }

    widget.onZapSent?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final remainingChars = ref.watch(remainingCharsProvider);
    final isShort = ref.watch(isShortProvider);
    final media = ref.watch(selectedMediaProvider);

    if (currentUser == null) {
      context.go("/login");
      return Text("Sign in");
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<bool>(
              value: isShort,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: false, child: Text('Zap')),
                DropdownMenuItem(value: true, child: Text('Short')),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref.read(isShortProvider.notifier).state = value;
                ref.read(selectedMediaProvider.notifier).state = [];
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () => _sendZap(currentUser.uid),
              child: Text(isShort ? 'Short' : 'Zap'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfilePicture(
                  pfp: currentUser.photoURL,
                  name: currentUser.displayName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLength: AppConstants.maxZapLength,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: "What's happening?",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isShort && media.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 300,
                child: VideoPlayerWidget(isFile: true, url: media.first.path),
              )
            else if (!isShort)
              _MediaPreview(
                mediaNotifier: media,
                onRemoveMedia: (file) {
                  ref.read(selectedMediaProvider.notifier).state = List.from(
                    media,
                  )..remove(file);
                },
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.perm_media_outlined),
                      onPressed: _pickMedia,
                    ),
                    if (isShort)
                      IconButton(
                        icon: const Icon(Icons.music_note),
                        onPressed: _addSong,
                      ),
                  ],
                ),
                Text(
                  remainingChars.toString(),
                  style: TextStyle(
                    color:
                        remainingChars < 0
                            ? Colors.red
                            : remainingChars < 20
                            ? Colors.orange
                            : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  final List<XFile> mediaNotifier;
  final void Function(XFile file) onRemoveMedia;

  const _MediaPreview({
    required this.mediaNotifier,
    required this.onRemoveMedia,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaNotifier.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          mediaNotifier.map((file) {
            final isVideo =
                file.path.toLowerCase().endsWith('.mp4') ||
                file.path.toLowerCase().endsWith('.mov') ||
                file.path.toLowerCase().endsWith('.avi');
            return Stack(
              children: [
                isVideo
                    ? SizedBox(
                      width: 100,
                      height: 100,
                      child: VideoPlayerWidget(isFile: true, url: file.path),
                    )
                    : AppImage.xFile(
                      file,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => onRemoveMedia(file),
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }
}
