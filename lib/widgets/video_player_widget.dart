import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:z/widgets/video_cache_manager.dart';

class VideoPlayerWidget extends StatefulWidget {
  final bool isFile;
  final String url;
  final double? width;
  final double? height;
  final void Function(double aspectRatio)? onAspectRatioCalculated;
  final void Function(VideoPlayerController controller)? onControllerChange;

  /// For Shorts-style autoplay control
  final bool? isPlaying;

  /// Disable fullscreen double-tap for Shorts
  final bool disableFullscreen;
  final bool thumbnailOnly;

  const VideoPlayerWidget({
    super.key,
    required this.isFile,
    required this.url,
    this.onControllerChange,
    this.width,
    this.height,
    this.onAspectRatioCalculated,
    this.isPlaying,
    this.thumbnailOnly = false,
    this.disableFullscreen = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  Duration _duration = Duration.zero;
  double _aspectRatio = 16 / 9;

  double get aspectRatio => _aspectRatio;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized && widget.isPlaying != null) {
      if (widget.isPlaying! && !_controller!.value.isPlaying) {
        _controller!.play();
      } else if (!widget.isPlaying! && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  Future<void> _setupCacheController() async {
    final cacheManager = VideoCacheManager.instance;
    final cachedFile = await cacheManager.getFileFromCache(widget.url);

    if (cachedFile != null && await cachedFile.file.exists()) {
      _controller = VideoPlayerController.file(cachedFile.file);
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      if (!widget.thumbnailOnly) {
        unawaited(cacheManager.downloadFile(widget.url));
      }
    }
  }

  Future<void> _initVideo() async {
    if (widget.isFile) {
      _controller = VideoPlayerController.file(File(widget.url));
    } else {
      await _setupCacheController();
    }
    if (_controller == null) throw Exception("Controller not initialized");

    try {
      if (widget.onControllerChange != null) {
        widget.onControllerChange!(_controller!);
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      _duration = _controller!.value.duration;
      _aspectRatio = _controller!.value.aspectRatio;
      widget.onAspectRatioCalculated?.call(_aspectRatio);
      await _controller!.pause();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      log("Video init error: $e");
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_isInitialized) return;
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  Future<void> _openFullScreen() async {
    if (!_isInitialized || widget.disableFullscreen) return;
    await _controller!.pause();
    if (!mounted || !context.mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder:
            (_, __, ___) => FullScreenVideoPlayer(controller: _controller!),
      ),
    );
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final videoWidget =
        widget.width != null && widget.height != null
            ? SizedBox(
              width: widget.width,
              height: widget.height,
              child: VideoPlayer(_controller!),
            )
            : AspectRatio(
              aspectRatio: _aspectRatio,
              child: Center(child: VideoPlayer(_controller!)),
            );
    if (widget.disableFullscreen) return videoWidget;
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _openFullScreen,
      child: Stack(
        alignment: Alignment.center,
        children: [
          videoWidget,
          if (!_controller!.value.isPlaying)
            Container(
              color: Colors.black38,
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 36,
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;

  const FullScreenVideoPlayer({super.key, required this.controller});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _controlsVisible = true;
  Duration _position = Duration.zero;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.play();

    _controller.addListener(() {
      if (mounted) {
        setState(() => _position = _controller.value.position);
      }
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideTimer(); // auto-hide after a few seconds
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startHideTimer();
  }

  Future<void> _closeFullScreen() async {
    await _controller.pause();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _controller.value.duration;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            if (_controlsVisible)
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: _closeFullScreen,
                ),
              ),
            if (_controlsVisible)
              Positioned(
                bottom: 60,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble().clamp(
                          0.0,
                          duration.inSeconds.toDouble(),
                        ),
                        max: duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          _controller.seekTo(Duration(seconds: value.toInt()));
                          _startHideTimer(); // reset hide timer on interaction
                        },
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_controlsVisible)
              Positioned(
                bottom: 10,
                child: IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    color: Colors.white,
                    size: 48,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                    _startHideTimer();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
