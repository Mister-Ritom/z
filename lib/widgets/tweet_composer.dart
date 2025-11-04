import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/video_player_widget.dart';
import '../providers/tweet_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/storage_provider.dart';
import '../utils/constants.dart';

class TweetComposer extends ConsumerStatefulWidget {
  final String? replyToTweetId;
  final VoidCallback? onTweetSent;

  const TweetComposer({super.key, this.replyToTweetId, this.onTweetSent});

  @override
  ConsumerState<TweetComposer> createState() => _TweetComposerState();
}

class _TweetComposerState extends ConsumerState<TweetComposer> {
  final _textController = TextEditingController();
  final ValueNotifier<List<XFile>> _selectedImages = ValueNotifier([]);
  final ValueNotifier<List<XFile>> _selectedVideos = ValueNotifier([]);
  int remainingChars = AppConstants.maxTweetLength;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final len = _textController.text.length;
      final newRemaining = AppConstants.maxTweetLength - len;
      if (remainingChars != newRemaining) {
        setState(() => remainingChars = newRemaining);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _selectedImages.dispose();
    _selectedVideos.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final total = _selectedImages.value.length + images.length;
    if (total > AppConstants.maxImagesPerTweet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum ${AppConstants.maxImagesPerTweet} images allowed',
            ),
          ),
        );
      }
      return;
    }

    _selectedImages.value = [..._selectedImages.value, ...images];
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    if (_selectedVideos.value.length >= AppConstants.maxVideosPerTweet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum ${AppConstants.maxVideosPerTweet} videos allowed',
            ),
          ),
        );
      }
      return;
    }

    _selectedVideos.value = [..._selectedVideos.value, video];
  }

  Future<void> _sendTweet() async {
    final currentUser = ref.read(currentUserModelProvider).valueOrNull;
    if (currentUser == null) return;

    final text = _textController.text.trim();
    final images = _selectedImages.value;
    final videos = _selectedVideos.value;

    if (text.isEmpty && images.isEmpty && videos.isEmpty) return;

    if (text.length > AppConstants.maxTweetLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tweet exceeds character limit')),
        );
      }
      return;
    }

    final id =
        FirebaseFirestore.instance
            .collection(AppConstants.tweetsCollection)
            .doc()
            .id;

    final tweetService = ref.read(tweetServiceProvider);
    final uploadService = ref.read(uploadNotifierProvider.notifier);

    // Chain uploads asynchronously
    Future(() async {
      try {
        List<String> imageUrls = [];
        List<String> videoUrls = [];

        // Upload images first (if any)
        if (images.isNotEmpty) {
          await uploadService.uploadFiles(
            files: images,
            type: UploadType.tweet,
            referenceId: id,
            onComplete: (urls) async {
              imageUrls = urls;

              // then upload videos if any
              if (videos.isNotEmpty) {
                await uploadService.uploadFiles(
                  files: videos,
                  type: UploadType.tweet,
                  referenceId: id,
                  onComplete: (vUrls) async {
                    videoUrls = vUrls;
                    await tweetService.createTweet(
                      tweetId: id,
                      userId: currentUser.id,
                      text: text,
                      imageUrls: imageUrls,
                      videoUrls: videoUrls,
                      parentTweetId: widget.replyToTweetId,
                    );
                  },
                );
              } else {
                await tweetService.createTweet(
                  tweetId: id,
                  userId: currentUser.id,
                  text: text,
                  imageUrls: imageUrls,
                  parentTweetId: widget.replyToTweetId,
                );
              }
            },
          );
        }
        // if no images, but videos exist
        else if (videos.isNotEmpty) {
          await uploadService.uploadFiles(
            files: videos,
            type: UploadType.tweet,
            referenceId: id,
            onComplete: (vUrls) async {
              videoUrls = vUrls;
              await tweetService.createTweet(
                tweetId: id,
                userId: currentUser.id,
                text: text,
                videoUrls: videoUrls,
                parentTweetId: widget.replyToTweetId,
              );
            },
          );
        }
        // if text only
        else {
          await tweetService.createTweet(
            tweetId: id,
            userId: currentUser.id,
            text: text,
            parentTweetId: widget.replyToTweetId,
          );
        }
      } catch (e, st) {
        log('Failed async tweet upload', error: e, stackTrace: st);
      }
    });

    // Instantly pop — background upload continues
    widget.onTweetSent?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _sendTweet,
              child: const Text('Tweet'),
            ),
          ),
        ],
      ),
      body:
          currentUser == null
              ? const Center(child: Text('Please sign in'))
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              currentUser.profilePictureUrl != null
                                  ? NetworkImage(currentUser.profilePictureUrl!)
                                  : null,
                          child:
                              currentUser.profilePictureUrl == null
                                  ? Text(
                                    currentUser.displayName[0].toUpperCase(),
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLength: AppConstants.maxTweetLength,
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
                    ValueListenableBuilder<List<XFile>>(
                      valueListenable: _selectedImages,
                      builder: (_, images, __) {
                        return ValueListenableBuilder<List<XFile>>(
                          valueListenable: _selectedVideos,
                          builder: (_, videos, __) {
                            if (images.isEmpty && videos.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...images.map(
                                  (image) => Stack(
                                    children: [
                                      AppImage.xFile(
                                        image,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _selectedImages.value = List.from(
                                              images,
                                            )..remove(image);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...videos.map(
                                  (video) => Stack(
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: VideoPlayerWidget(
                                          isFile: true,
                                          url: video.path,
                                        ),
                                      ),
                                      Positioned(
                                        top: -12,
                                        right: -8,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _selectedVideos.value = List.from(
                                              videos,
                                            )..remove(video);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image_outlined),
                              onPressed: _pickImage,
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam_outlined),
                              onPressed: _pickVideo,
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
