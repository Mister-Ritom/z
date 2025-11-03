import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  bool _isUploading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.length + _selectedImages.length >
        AppConstants.maxImagesPerTweet) {
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

    setState(() {
      for (final image in images) {
        _selectedImages.add(File(image.path));
      }
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      setState(() {
        _selectedVideo = File(video.path);
        _selectedImages.clear();
      });
    }
  }

  Future<void> _sendTweet() async {
    final currentUser = ref.read(currentUserModelProvider).valueOrNull;
    if (currentUser == null) return;

    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty && _selectedVideo == null) {
      return;
    }

    if (text.length > AppConstants.maxTweetLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tweet exceeds character limit')),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final tweetService = ref.read(tweetServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      List<String> imageUrls = [];
      String? videoUrl;

      // Upload images
      if (_selectedImages.isNotEmpty) {
        imageUrls = await storageService.uploadTweetImages(
          _selectedImages,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      // Upload video
      if (_selectedVideo != null) {
        videoUrl = await storageService.uploadTweetVideo(
          _selectedVideo!,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      // Create tweet
      await tweetService.createTweet(
        userId: currentUser.id,
        text: text,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        parentTweetId: widget.replyToTweetId,
      );

      // Reset composer
      _textController.clear();
      setState(() {
        _selectedImages.clear();
        _selectedVideo = null;
        _isUploading = false;
      });

      widget.onTweetSent?.call();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      setState(() {
        _isUploading = false;
      });
      log("Failed to send tweet", error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send tweet: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    final remainingChars =
        AppConstants.maxTweetLength - _textController.text.length;

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
              onPressed: _isUploading ? null : _sendTweet,
              child: const Text('Tweet'),
            ),
          ),
        ],
      ),
      body:
          currentUser == null
              ? const Center(child: Text('Please sign in'))
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info and text field
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                currentUser.profilePictureUrl != null
                                    ? NetworkImage(
                                      currentUser.profilePictureUrl!,
                                    )
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
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      // Media preview
                      if (_selectedImages.isNotEmpty ||
                          _selectedVideo != null) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._selectedImages.map(
                              (image) => Stack(
                                children: [
                                  Image.file(
                                    image,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImages.remove(image);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedVideo != null)
                              Stack(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: VideoPlayerWidget(
                                      isFile: true,
                                      url:
                                          _selectedVideo!
                                              .path, // since _selectedVideo is a File
                                    ),
                                  ),
                                  Positioned(
                                    top: -12,
                                    right: -8,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedVideo = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Actions and character count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Media buttons
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.image_outlined),
                                onPressed:
                                    _selectedVideo == null ? _pickImage : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.videocam_outlined),
                                onPressed:
                                    _selectedImages.isEmpty ? _pickVideo : null,
                              ),
                            ],
                          ),
                          // Character count
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
              ),
    );
  }
}
