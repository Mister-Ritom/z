import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:z/models/story_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/profile_picture.dart';
import 'package:z/widgets/video_player_widget.dart';

class StoryItemScreen extends ConsumerStatefulWidget {
  final List<StoryModel> userStories;
  final String userId;
  final VoidCallback onNextUser;
  final VoidCallback onPreviousUser;

  const StoryItemScreen({
    super.key,
    required this.userStories,
    required this.userId,
    required this.onNextUser,
    required this.onPreviousUser,
  });

  @override
  ConsumerState<StoryItemScreen> createState() => _StoryItemScreenState();
}

class _StoryItemScreenState extends ConsumerState<StoryItemScreen> {
  int currentIndex = 0;
  Timer? _timer;
  double progress = 0.0;

  StoryModel get currentStory => widget.userStories[currentIndex];

  @override
  void initState() {
    super.initState();
    _startStoryTimer();
  }

  void _startStoryTimer() {
    _timer?.cancel();
    progress = 0.0;
    final duration = currentStory.duration;

    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() => progress += 50 / duration.inMilliseconds);
      if (progress >= 1.0) {
        _nextStory();
      }
    });
  }

  void _nextStory() {
    _timer?.cancel();
    if (currentIndex < widget.userStories.length - 1) {
      setState(() => currentIndex++);
      _startStoryTimer();
    } else {
      widget.onNextUser();
    }
  }

  void _previousStory() {
    _timer?.cancel();
    if (currentIndex > 0) {
      setState(() => currentIndex--);
      _startStoryTimer();
    } else {
      widget.onPreviousUser();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildProgressBars() {
    return Row(
      children:
          widget.userStories.map((story) {
            final storyIndex = widget.userStories.indexOf(story);
            final value =
                storyIndex < currentIndex
                    ? 1.0
                    : storyIndex == currentIndex
                    ? progress
                    : 0.0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 2,
                ),
              ),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider(widget.userId));

    return GestureDetector(
      onTapDown: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 2) {
          _previousStory();
        } else {
          _nextStory();
        }
      },
      child: Stack(
        children: [
          Center(child: _buildStoryMedia(currentStory)),
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressBars(),
                const SizedBox(height: 10),
                userAsync.when(
                  data: (user) => _buildUserInfo(user),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) {
                    log('Error loading user data: $e');
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
          if (currentStory.caption.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 8,
              right: 8,
              child: _buildBackgroundBlur(
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    currentStory.caption,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoryMedia(StoryModel story) {
    try {
      if (Helpers.isVideoPath(story.mediaUrl)) {
        return VideoPlayerWidget(
          url: story.mediaUrl,
          isFile: false,
          disableFullscreen: true,
          isPlaying: true,
        );
      } else {
        return AppImage.network(
          story.mediaUrl,
          fit: BoxFit.cover,
          onDoubleTap: () {},
        );
      }
    } catch (e, st) {
      log('Error loading story media: $e\n$st');
      return const Center(child: Icon(Icons.error, color: Colors.white));
    }
  }

  Widget _buildBackgroundBlur(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withOpacityAlpha(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: child,
        ),
      ),
    );
  }

  Widget _buildUserInfo(UserModel? user) {
    if (user == null) return const SizedBox.shrink();

    return _buildBackgroundBlur(
      Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back),
          ),
          ProfilePicture(pfp: user.profilePictureUrl, name: user.displayName),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              Text(
                timeago.format(currentStory.createdAt),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
