import 'package:flutter/material.dart';
import 'package:z/models/story_model.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/media/video_player_widget.dart';

class StoryMedia extends StatelessWidget {
  final StoryModel story;
  final bool isPlaying;

  const StoryMedia({super.key, required this.story, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    try {
      if (Helpers.isVideoPath(story.mediaUrl)) {
        return VideoPlayerWidget(
          url: story.mediaUrl,
          isFile: false,
          disableFullscreen: true,
          isPlaying: isPlaying,
        );
      }
      return AppImage.network(story.mediaUrl, fit: BoxFit.cover);
    } catch (e, st) {
      AppLogger.error(
        'StoryMedia',
        'Error loading story media',
        error: e,
        stackTrace: st,
      );
      return const Center(child: Icon(Icons.error, color: Colors.white));
    }
  }
}
