import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:z/models/ad_model.dart';
import 'package:z/models/story_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/analytics_providers.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/services/ad_manager.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/ad_widgets.dart';
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

class _StoryItemScreenState extends ConsumerState<StoryItemScreen>
    with SingleTickerProviderStateMixin {
  int currentUserIndex = 0;
  int currentStoryIndex = 0;
  Timer? _timer;
  double progress = 0.0;
  bool _pause = false;
  Duration longPressThreshold = const Duration(milliseconds: 300);
  Timer? _pressTimer;
  bool _isLongPressing = false;
  final AdManager _adManager = AdManager();

  double _dragOffsetY = 0.0;
  bool _isDragging = false;
  late final AnimationController _animController;
  late Animation<double> _anim;
  static const double _dismissThreshold = 120.0;
  static const double _velocityThreshold = 700.0;

  String get currentUserId => widget.allUserIds[currentUserIndex];
  List<StoryModel> get currentUserStories =>
      widget.groupedStories[currentUserId]!.cast<StoryModel>();
  StoryModel get currentStory => currentUserStories[currentStoryIndex];

  @override
  void initState() {
    super.initState();
    currentUserIndex = widget.initialUserIndex;
    currentStoryIndex = widget.initialStoryIndex;
    _animController = AnimationController(vsync: this);
    _anim = Tween<double>(begin: 0, end: 0).animate(_animController)
      ..addListener(() {
        setState(() {
          _dragOffsetY = _anim.value;
        });
      });
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
      if (!_pause && !_isDragging) {
        setState(() => progress += 50 / duration.inMilliseconds);
        if (progress >= 1.0) _nextStory();
      }
    });
  }

  void _nextStory() {
    _timer?.cancel();
    
    // Check if we should show an ad
    if (_adManager.shouldShowStoryAd()) {
      _showStoryAd(() {
        // Continue to next story after ad
        _continueToNextStory();
      });
      return;
    }
    
    _continueToNextStory();
  }

  void _continueToNextStory() {
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
    
    // Check if we should show an ad
    if (_adManager.shouldShowStoryAd()) {
      _showStoryAd(() {
        // Continue to previous story after ad
        _continueToPreviousStory();
      });
      return;
    }
    
    _continueToPreviousStory();
  }

  void _continueToPreviousStory() {
    if (currentStoryIndex > 0) {
      setState(() => currentStoryIndex--);
      _startStoryTimer();
    } else {
      _previousUser();
    }
  }

  void _showStoryAd(VoidCallback onDismissed) {
    final adType = _adManager.getRandomAdType();
    
    if (adType == AdType.interstitial || adType == AdType.video) {
      // Show full-screen ad
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: adType == AdType.video
              ? VideoAdWidget(
                  showSkipButton: true,
                  skipDelay: const Duration(seconds: 5),
                  onAdDismissed: () {
                    Navigator.pop(context);
                    onDismissed();
                  },
                )
              : InterstitialAdWidget(
                  onAdDismissed: () {
                    Navigator.pop(context);
                    onDismissed();
                  },
                ),
        ),
      );
    } else {
      // Show native ad overlay
      showModalBottomSheet(
        context: context,
        isDismissible: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: NativeAdWidget(
                  showSkipButton: true,
                ),
              ),
            ],
          ),
        ),
      ).then((_) => onDismissed());
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
    _animController.dispose();
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

  void _animateBackTo(double target, {int ms = 200}) {
    try {
      _animController.stop();
      _animController.duration = Duration(milliseconds: ms);
      _anim = Tween<double>(begin: _dragOffsetY, end: target).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );
      _animController.reset();
      _animController.forward();
    } catch (e, st) {
      log('Error animating drag: $e\n$st');
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    try {
      _isDragging = false;
      final velocity = details.primaryVelocity ?? 0.0;
      if (_dragOffsetY > _dismissThreshold || velocity > _velocityThreshold) {
        final screenHeight = MediaQuery.of(context).size.height;
        _animateBackTo(screenHeight, ms: 250);
        _animController.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            try {
              Navigator.pop(context);
            } catch (e, st) {
              log('Error popping after dismiss: $e\n$st');
            }
          }
        });
      } else if (_dragOffsetY < -_dismissThreshold ||
          velocity < -_velocityThreshold) {
        final screenHeight = MediaQuery.of(context).size.height;
        _animateBackTo(-screenHeight, ms: 250);
        _animController.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            try {
              Navigator.pop(context);
            } catch (e, st) {
              log('Error popping after dismiss: $e\n$st');
            }
          }
        });
      } else {
        _animateBackTo(0.0, ms: 200);
        setState(() => _pause = false);
      }
    } catch (e, st) {
      log('Error during drag end: $e\n$st');
      _animateBackTo(0.0, ms: 200);
      setState(() => _pause = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider(currentUserId));
    final analyticsService = ref.watch(storyAnalyticsProvider);

    final screenHeight = MediaQuery.of(context).size.height;
    final dragAbs = _dragOffsetY.abs();
    final opacity = (1.0 - (dragAbs / (screenHeight * 0.7))).clamp(0.0, 1.0);
    final scale = (1.0 - (dragAbs / (screenHeight * 6))).clamp(0.85, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          if (_isDragging) return;
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
          if (_isDragging) return;
          _pressTimer?.cancel();
          if (_isLongPressing) {
            setState(() {
              _pause = false;
            });
          } else {
            final width = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < width / 2) {
              _previousStory();
            } else {
              _nextStory();
            }
          }
        },
        onTapCancel: () {
          if (_isDragging) return;
          _pressTimer?.cancel();
          if (_isLongPressing) {
            setState(() => _pause = false);
          }
        },
        onVerticalDragStart: (details) {
          _isDragging = true;
          _pressTimer?.cancel();
          setState(() => _pause = true);
        },
        onVerticalDragUpdate: (details) {
          try {
            _dragOffsetY += details.delta.dy;
            setState(() {});
          } catch (e, st) {
            log('Error during drag update: $e\n$st');
          }
        },
        onVerticalDragEnd: _handleDragEnd,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(opacity: opacity, child: child),
              ),
            );
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
                  child: _buildBackgroundBlur(
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        currentStory.caption,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 80,
                right: 10,
                child: StreamBuilder<bool>(
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
              ),
            ],
          ),
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
          isPlaying: !_pause && !_isDragging,
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
