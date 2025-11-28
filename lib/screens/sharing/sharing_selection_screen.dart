import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/sharing_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/providers/stories_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/utils/constants.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/media/video_player_widget.dart';
import '../../models/story_model.dart';
import '../../providers/profile_provider.dart';

class SharingSelectionScreen extends ConsumerStatefulWidget {
  final List<SharedMediaFile> sharedFiles;

  const SharingSelectionScreen({super.key, required this.sharedFiles});

  @override
  ConsumerState<SharingSelectionScreen> createState() =>
      _SharingSelectionScreenState();
}

class _SharingSelectionScreenState
    extends ConsumerState<SharingSelectionScreen> {
  String? _selectedOption;
  final _textController = TextEditingController();
  StoryVisibility _visibility = StoryVisibility.public;
  bool _isUploading = false;
  List<XFile>? _xFiles;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final sharingService = ref.read(sharingServiceProvider);
    final xFiles = await sharingService.convertToXFiles(widget.sharedFiles);
    if (mounted) {
      setState(() {
        _xFiles = xFiles;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _isSingleVideo {
    return widget.sharedFiles.length == 1 &&
        widget.sharedFiles.first.type == SharedMediaType.video;
  }

  bool get _hasOnlyImages {
    return widget.sharedFiles.isNotEmpty &&
        widget.sharedFiles.every((file) => file.type == SharedMediaType.image);
  }

  Future<List<String>> _getVisibleTo(String userId) async {
    final followers = await ref.read(userFollowersProvider(userId).future);
    final following = await ref.read(userFollowingProvider(userId).future);
    switch (_visibility) {
      case StoryVisibility.public:
        return [];
      case StoryVisibility.followers:
        return followers;
      case StoryVisibility.mutual:
        return followers.where((f) => following.contains(f)).toList();
    }
  }

  Future<void> _createZap(List<XFile> files, bool isShort) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isUploading = true);

    final id =
        FirebaseFirestore.instance
            .collection(
              isShort
                  ? AppConstants.shortsCollection
                  : AppConstants.zapsCollection,
            )
            .doc()
            .id;

    final uploadNotifier = ref.read(uploadNotifierProvider.notifier);
    final zapService = ref.read(zapServiceProvider(isShort));

    try {
      uploadNotifier.uploadFiles(
        files: files,
        type: isShort ? UploadType.shorts : UploadType.zap,
        referenceId: id,
        onComplete: (urls) async {
          await zapService.createZap(
            zapId: id,
            userId: user.uid,
            text: _textController.text.trim(),
            mediaUrls: urls,
          );
          if (mounted) {
            setState(() => _isUploading = false);
            context.pop();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating zap: $e')));
      }
    }
  }

  Future<void> _createStory(XFile file) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isUploading = true);

    final visibleTo = await _getVisibleTo(user.uid);
    final uploadNotifier = ref.read(uploadNotifierProvider.notifier);
    final service = ref.read(storyServiceProvider);

    try {
      uploadNotifier.uploadFiles(
        files: [file],
        type: UploadType.document,
        referenceId: user.uid,
        onComplete: (urls) async {
          await service.createStory(
            uid: user.uid,
            caption: _textController.text.trim(),
            mediaUrl: urls.first,
            visibility: _visibility,
            visibleTo: visibleTo,
          );
          if (mounted) {
            setState(() => _isUploading = false);
            context.pop();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating story: $e')));
      }
    }
  }

  void _handleSubmit() {
    if (_selectedOption == null || _xFiles == null || _xFiles!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an option')));
      return;
    }

    switch (_selectedOption) {
      case 'zap':
        _createZap(_xFiles!, false);
        break;
      case 'story':
        if (_xFiles!.length == 1) {
          _createStory(_xFiles!.first);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stories can only contain one media file'),
            ),
          );
        }
        break;
      case 'short':
        if (_isSingleVideo && _xFiles!.length == 1) {
          _createZap(_xFiles!, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shorts can only contain a single video'),
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_xFiles == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      context.go('/login');
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share to'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Media Preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media preview
                  if (_xFiles!.length == 1)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          Helpers.isVideoPath(_xFiles!.first.path)
                              ? SizedBox(
                                height: 300,
                                child: VideoPlayerWidget(
                                  isFile: true,
                                  url: _xFiles!.first.path,
                                ),
                              )
                              : AppImage.xFile(_xFiles!.first),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _xFiles!.map((file) {
                            final isVideo = Helpers.isVideoPath(file.path);
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  isVideo
                                      ? SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: VideoPlayerWidget(
                                          isFile: true,
                                          url: file.path,
                                        ),
                                      )
                                      : AppImage.xFile(
                                        file,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                            );
                          }).toList(),
                    ),
                  const SizedBox(height: 16),
                  // Text input
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Add a caption...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  // Selection options
                  const Text(
                    'Share as:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Radio group for selection options
                  RadioGroup<String>(
                    groupValue: _selectedOption,
                    onChanged: (value) {
                      setState(() => _selectedOption = value);
                    },
                    child: Column(
                      children: [
                        // Zap option
                        RadioListTile<String>(
                          title: const Text('Zap (Post)'),
                          subtitle: Text(
                            _hasOnlyImages
                                ? 'Share ${_xFiles!.length} image(s) as a post'
                                : 'Share ${_xFiles!.length} media file(s) as a post',
                          ),
                          value: 'zap',
                        ),
                        // Story option (only if single media)
                        if (widget.sharedFiles.length == 1)
                          RadioListTile<String>(
                            title: const Text('Story'),
                            subtitle: const Text('Share as a story (24 hours)'),
                            value: 'story',
                          ),
                        // Short option (only if single video)
                        if (_isSingleVideo)
                          RadioListTile<String>(
                            title: const Text('Short Video'),
                            subtitle: const Text('Share as a short video'),
                            value: 'short',
                          ),
                      ],
                    ),
                  ),
                  // Story visibility (only if story is selected)
                  if (_selectedOption == 'story')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Story Visibility:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DropdownButtonFormField<StoryVisibility>(
                            initialValue: _visibility,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items:
                                StoryVisibility.values
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v.name.toUpperCase()),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _visibility = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Submit button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _handleSubmit,
                child:
                    _isUploading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          _selectedOption == 'zap'
                              ? 'Post Zap'
                              : _selectedOption == 'story'
                              ? 'Post Story'
                              : _selectedOption == 'short'
                              ? 'Post Short'
                              : 'Share',
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
