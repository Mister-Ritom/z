import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:z/models/story_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/profile_picture.dart';
import 'package:z/widgets/video_player_widget.dart';

class StoryItemScreen extends ConsumerStatefulWidget {
  final Map<String, List<dynamic>> groupedStories;
  final List<String> allUserIds;
  final int initialUserIndex;
  final int initialStoryIndex;

  const StoryItemScreen({
    super.key,
    required this.groupedStories,
    required this.allUserIds,
    required this.initialUserIndex,
    required this.initialStoryIndex,
  });

  @override
  ConsumerState<StoryItemScreen> createState() => _StoryItemScreenState();
}

class _StoryItemScreenState extends ConsumerState<StoryItemScreen> {
  int currentUserIndex = 0;
  int currentStoryIndex = 0;
  Timer? _timer;
  double progress = 0.0;
  bool _pause = false;
  Duration longPressThreshold = const Duration(milliseconds: 300);
  Timer? _pressTimer;
  bool _isLongPressing = false;

  String get currentUserId => widget.allUserIds[currentUserIndex];
  List<StoryModel> get currentUserStories =>
      widget.groupedStories[currentUserId]!.cast<StoryModel>();
  StoryModel get currentStory => currentUserStories[currentStoryIndex];

  @override
  void initState() {
    super.initState();
    currentUserIndex = widget.initialUserIndex;
    currentStoryIndex = widget.initialStoryIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _markStoryViewed());
    _startStoryTimer();
  }

  void _markStoryViewed() {
    final analyticsService = ref.read(storyAnalyticsProvider);
    analyticsService.viewStory(currentUserId, currentStory.id).catchError((e) {
      log('Error marking story viewed: $e');
    });
  }

  void _startStoryTimer() {
    _timer?.cancel();
    progress = 0.0;
    final duration = currentStory.duration;

    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_pause) {
        setState(() => progress += 50 / duration.inMilliseconds);
        if (progress >= 1.0) _nextStory();
      }
    });
  }

  void _nextStory() {
    _timer?.cancel();
    if (currentStoryIndex < currentUserStories.length - 1) {
      setState(() => currentStoryIndex++);
      _markStoryViewed();
      _startStoryTimer();
    } else {
      _nextUser();
    }
  }

  void _previousStory() {
    _timer?.cancel();
    if (currentStoryIndex > 0) {
      setState(() => currentStoryIndex--);
      _startStoryTimer();
    } else {
      _previousUser();
    }
  }

  void _nextUser() {
    if (currentUserIndex < widget.allUserIds.length - 1) {
      setState(() {
        currentUserIndex++;
        currentStoryIndex = 0;
      });
      _markStoryViewed();
      _startStoryTimer();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousUser() {
    if (currentUserIndex > 0) {
      setState(() {
        currentUserIndex--;
        currentStoryIndex = 0;
      });
      _markStoryViewed();
      _startStoryTimer();
    } else {
      Navigator.pop(context);
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
          currentUserStories.map((story) {
            final storyIndex = currentUserStories.indexOf(story);
            final value =
                storyIndex < currentStoryIndex
                    ? 1.0
                    : storyIndex == currentStoryIndex
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
    final userAsync = ref.watch(userProfileProvider(currentUserId));
    final analyticsService = ref.watch(storyAnalyticsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          setState(() {
            _isLongPressing = false;
          });
          _pressTimer?.cancel();
          _pressTimer = Timer(longPressThreshold, () {
            setState(() {
              _pause = true;
              _isLongPressing = true;
            });
          });
        },
        onTapUp: (details) {
          _pressTimer?.cancel();
          if (_isLongPressing) {
            // Finger was held long enough, just unpause
            setState(() {
              _pause = false;
            });
          } else {
            // Finger was quickly tapped, go next/previous
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width / 2) {
              _previousStory();
            } else {
              _nextStory();
            }
          }
        },
        onTapCancel: () {
          _pressTimer?.cancel();
          if (_isLongPressing) {
            setState(() => _pause = false);
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
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildBackgroundBlur(
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            currentStory.caption,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: analyticsService.isStoryLikedStream(
                        currentUserId,
                        currentStory.id,
                      ),
                      initialData: false,
                      builder: (context, snapshot) {
                        final isLiked = snapshot.data ?? false;
                        return IconButton(
                          onPressed: () {
                            analyticsService.toggleLikeStory(
                              currentUserId,
                              currentStory.id,
                            );
                          },
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
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
          isPlaying: !_pause,
        );
      } else {
        return AppImage.network(story.mediaUrl, fit: BoxFit.cover);
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
          color: Colors.black.withOpacityAlpha(0.3),
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
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          ProfilePicture(pfp: user.profilePictureUrl, name: user.displayName),
          const SizedBox(width: 10),
          Column(
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
