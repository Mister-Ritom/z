import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z/screens/creation/abstract_page.dart';
import 'package:z/widgets/media/camera_view.dart';
import 'package:z/widgets/media/video_player_widget.dart';

class ShortsCreation extends ConsumerStatefulWidget {
  const ShortsCreation({super.key});

  @override
  ConsumerState<ShortsCreation> createState() => ShortsCreationState();
}

class ShortsCreationState extends ConsumerState<ShortsCreation>
    implements CreationPage {
  final mediaProvider = StateProvider<XFile?>((ref) => null);

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
          CoolTextField(hintText: "Add Caption...", maxLines: 3),
        ],
      ),
    );
  }

  @override
  Future<CreationResult?> onNext() async {
    return CreationResult.success;
  }
}
