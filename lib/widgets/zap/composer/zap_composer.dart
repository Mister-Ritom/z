import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z/models/song_model.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/services/analytics/firebase_analytics_service.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/common/profile_picture.dart';
import 'package:z/widgets/media/video_player_widget.dart';
import 'package:z/widgets/song/song_picker_dialog.dart';

import 'media_preview.dart';

class ZapComposer extends ConsumerStatefulWidget {
  final String? replyToZapId;
  final VoidCallback? onZapSent;
  final List<XFile>? initialMedia;
  final bool? initialIsShort;

  const ZapComposer({
    super.key,
    this.replyToZapId,
    this.onZapSent,
    this.initialMedia,
    this.initialIsShort,
  });

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
  final selectedSongProvider = StateProvider<SongModel?>((ref) => null);

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMedia != null && widget.initialMedia!.isNotEmpty) {
        ref.read(selectedMediaProvider.notifier).state = widget.initialMedia!;
      }
      if (widget.initialIsShort != null) {
        ref.read(isShortProvider.notifier).state = widget.initialIsShort!;
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
    final isShort = ref.read(isShortProvider);
    if (!isShort) return;

    final song = await showModalBottomSheet<SongModel>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SongPickerDialog(),
    );

    if (song == null) return;

    ref.read(selectedSongProvider.notifier).state = song;
  }

  Future<XFile> _makeVideoSilent(XFile original) async {
    final editor = VideoEditorBuilder(videoPath: original.path).removeAudio();
    final outputPath = await editor.export();
    if (outputPath == null) throw Exception("couldn't edit");
    return XFile(outputPath);
  }

  Future<void> _sendZap(String currentUserId) async {
    final text = _textController.text.trim();
    final media = ref.read(selectedMediaProvider);
    final isShort = ref.read(isShortProvider);
    final selectedSong = ref.read(selectedSongProvider);

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
        List<XFile> filesToUpload = media;

        if (isShort && selectedSong != null && media.isNotEmpty) {
          final silentVideo = await _makeVideoSilent(media.first);
          filesToUpload = [silentVideo];
        }

        uploadService.uploadFiles(
          files: filesToUpload,
          type: isShort ? UploadType.shorts : UploadType.zap,
          referenceId: id,
          onComplete: (urls) async {
            await zapService.createZap(
              zapId: id,
              userId: currentUserId,
              text: text,
              mediaUrls: urls,
              parentZapId: widget.replyToZapId,
              songId: selectedSong?.id,
            );
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
        await FirebaseAnalyticsService.logPostCreated(
          contentType: 'text',
          isShort: isShort,
        );
      }
      AppLogger.info(
        'ZapComposer',
        'Zap created successfully',
        data: {
          'zapId': id,
          'isShort': isShort,
          'hasMedia': media.isNotEmpty,
          'songId': selectedSong?.id,
        },
      );
    } catch (e, st) {
      AppLogger.error(
        'ZapComposer',
        'Failed to create zap',
        error: e,
        stackTrace: st,
        data: {'isShort': isShort, 'hasMedia': media.isNotEmpty},
      );
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
    final selectedSong = ref.watch(selectedSongProvider);

    if (currentUser == null) {
      context.go("/login");
      return const Text("Sign in");
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
                if (!value) {
                  ref.read(selectedSongProvider.notifier).state = null;
                }
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
              ZapMediaPreview(
                media: media,
                onRemoveMedia: (file) {
                  ref.read(selectedMediaProvider.notifier).state = List.from(
                    media,
                  )..remove(file);
                },
              ),
            if (isShort && selectedSong != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(selectedSong.coverUrl),
                  ),
                  title: Text(selectedSong.title),
                  subtitle: Text(selectedSong.artist),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(selectedSongProvider.notifier).state = null;
                    },
                  ),
                ),
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
