import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/providers/stories_provider.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/media/camera_view.dart';
import 'package:z/widgets/media/video_player_widget.dart';
import '../../models/story_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics/firebase_analytics_service.dart';

class StoryCreationScreen extends ConsumerStatefulWidget {
  final XFile? initialFile;
  
  const StoryCreationScreen({super.key, this.initialFile});

  @override
  ConsumerState<StoryCreationScreen> createState() =>
      _StoryCreationScreenState();
}

class _StoryCreationScreenState extends ConsumerState<StoryCreationScreen> {
  StoryVisibility _visibility = StoryVisibility.public;
  XFile? _file;
  bool _opened = false;
  final _textController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Use initial file if provided, otherwise pick media
        if (widget.initialFile != null) {
          if (mounted) {
            setState(() => _file = widget.initialFile);
          }
        } else {
          final media = await _pickMedia();
          if (mounted) {
            if (media != null) {
              setState(() => _file = media);
            } else {
              Navigator.pop(context);
            }
          }
        }
      });
    }
  }

  Future<XFile?> _pickMedia() async {
    final List<XFile>? files = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CameraView(limit: 1),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    return (files != null && files.isNotEmpty) ? files.first : null;
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

  Future<void> _createStory(XFile file) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final visibleTo = await _getVisibleTo(user.uid);
    final uploadNotifier = ref.read(uploadNotifierProvider.notifier);
    final service = ref.read(storyServiceProvider);

    uploadNotifier.uploadFiles(
      files: [file],
      type: UploadType.document,
      referenceId: user.uid,
      onComplete: (urls) async {
        try {
          final mediaUrl = urls.first;
          await service.createStory(
            uid: user.uid,
            caption: _textController.text.trim(),
            mediaUrl: mediaUrl,
            visibility: _visibility,
            visibleTo: visibleTo,
          );
          // Track story creation in Firebase Analytics
          await FirebaseAnalyticsService.logStoryCreated();
        } catch (e, stackTrace) {
          // Report error to Crashlytics
          await FirebaseAnalyticsService.recordError(
            e,
            stackTrace,
            reason: 'Failed to create story',
            fatal: false,
          );
        }
      },
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Story'),
        actions: [
          SizedBox(
            width: 100,
            child: DropdownButtonFormField<StoryVisibility>(
              initialValue: _visibility,
              onChanged: (v) => setState(() => _visibility = v!),
              items:
                  StoryVisibility.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(v.name.toUpperCase()),
                          ),
                        ),
                      )
                      .toList(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Visibility',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              isExpanded: true, // ensures dropdown fits the SizedBox width
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () async => await _createStory(_file!),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    Helpers.isVideoPath(_file!.path)
                        ? VideoPlayerWidget(isFile: true, url: _file!.path)
                        : AppImage.xFile(_file!),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(label: Text("Caption")),
              controller: _textController,
            ),
          ],
        ),
      ),
    );
  }
}
