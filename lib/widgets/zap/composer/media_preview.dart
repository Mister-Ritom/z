import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/media/video_player_widget.dart';

class ZapMediaPreview extends StatelessWidget {
  final List<XFile> media;
  final void Function(XFile file) onRemoveMedia;

  const ZapMediaPreview({
    super.key,
    required this.media,
    required this.onRemoveMedia,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          media.map((file) {
            final lowerPath = file.path.toLowerCase();
            final isVideo =
                lowerPath.endsWith('.mp4') ||
                lowerPath.endsWith('.mov') ||
                lowerPath.endsWith('.avi');

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
