import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z/screens/creation/abstract_page.dart';
import 'package:z/widgets/media/camera_view.dart';
import 'package:z/widgets/media/video_player_widget.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/services/content/zaps/zap_service.dart';
import 'package:z/models/zap_model.dart';

class ShortsCreation extends ConsumerStatefulWidget {
  final List<XFile>? initialMedia;
  final String? initialText;
  const ShortsCreation({super.key, this.initialMedia, this.initialText});

  @override
  ConsumerState<ShortsCreation> createState() => ShortsCreationState();
}

class ShortsCreationState extends ConsumerState<ShortsCreation>
    implements CreationPage {
  final mediaProvider = StateProvider<XFile?>((ref) => null);
  late final TextEditingController captionController;

  @override
  void initState() {
    super.initState();
    captionController = TextEditingController(text: widget.initialText);
    if (widget.initialMedia != null && widget.initialMedia!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mediaProvider.notifier).state = widget.initialMedia!.first;
      });
    }
  }

  Future<XFile?> _pickVideo() async {
    final List<XFile>? files = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => const CameraView(
              limit: 1,
              title: "Shorts Camera",
              mode: CameraMode.video,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    return (files != null && files.isNotEmpty) ? files.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(mediaProvider);

    return SingleChildScrollView(
      child: CoolColumn(
        margin: const EdgeInsets.all(12),
        divider: const SizedBox(height: 12),
        children: [
          GestureDetector(
            onTap: () async {
              final video = await _pickVideo();
              if (video != null && mounted) {
                ref.read(mediaProvider.notifier).state = video;
              }
            },
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.orange,
                      Colors.deepPurple,
                      Colors.blueAccent,
                    ],
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    media != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: VideoPlayerWidget(
                            isFile: true,
                            url: media.path,
                          ),
                        )
                        : Center(
                          child: Text(
                            "No media selected",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
              ),
            ),
          ),
          CoolTextField(
            hintText: "Add Caption...",
            maxLines: 3,
            controller: captionController,
          ),
          SizedBox(height: 128),
        ],
      ),
    );
  }

  @override
  Future<CreationResult?> onNext() async {
    final String text = captionController.text.trim();
    final media = ref.read(mediaProvider);

    if (media == null && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot upload empty shorts")),
      );
      return CreationResult.stay;
    }

    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not authenticated")));
      return CreationResult.stay;
    }

    // Shorts are basically Zaps with isShort: true
    final zapService = ref.read(zapServiceProvider(true));

    _handleBackgroundShortsCreation(
      text: text,
      userId: currentUserId,
      media: media,
      zapService: zapService,
    );

    return CreationResult.success;
  }

  void _handleBackgroundShortsCreation({
    required String text,
    required String userId,
    required XFile? media,
    required ZapService zapService,
  }) async {
    try {
      List<String> urls = [];
      if (media != null) {
        final uploadService = ref.read(uploadNotifierProvider.notifier);
        urls = await uploadService.uploadFiles(
          files: [media],
          type: UploadType.shorts,
          referenceId: userId,
        );
      }

      final zap = ZapModel(
        id: userId + DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        text: text,
        mediaUrls: urls,
        createdAt: DateTime.now(),
        isShort: true,
      );

      await zapService.createZap(zap);
    } catch (e) {
      // Log error
    }
  }
}
