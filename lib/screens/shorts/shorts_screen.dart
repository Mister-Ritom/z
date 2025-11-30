import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/services/ads/ad_manager.dart';
import 'package:z/services/content/recommendations/recommendation_cache_service.dart';
import 'package:z/widgets/ads/ad_widgets.dart';
import 'package:z/widgets/media/short_video/short_video_widget.dart';

class ShortsScreen extends ConsumerStatefulWidget {
  final bool isActive; // parent tells if this page is active
  const ShortsScreen({super.key, required this.isActive});

  @override
  ConsumerState<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends ConsumerState<ShortsScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController(viewportFraction: 0.99);
  VideoPlayerController? _currentController;
  final AdManager _adManager = AdManager();
  bool _showingAd = false;
  bool _hasInitialized = false;

  int _currentIndex = 0;
  late final _forYouFeed = forYouFeedProvider(true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _hasInitialized = true;
      
      // Load lastViewedZapId from cache
      final cacheService = RecommendationCacheService();
      final lastViewedZapId = await cacheService.getLastViewedZapId(isShort: true);
      
      await ref.read(_forYouFeed.notifier).loadInitial(
        lastViewedZapId: lastViewedZapId,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShortsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Page became inactive → pause
    if (!widget.isActive && oldWidget.isActive) {
      _currentController?.pause();
    }

    // Page became active → play current video
    if (widget.isActive && !oldWidget.isActive) {
      _currentController?.play();
    }
  }

  @override
  bool get wantKeepAlive => true; // keeps state in IndexedStack

  Future<void> _onRefresh() async {
    await ref.read(_forYouFeed.notifier).refreshFeed();
  }

  void _showShortsAd() {
    if (!mounted || _showingAd) return;

    setState(() {
      _showingAd = true;
    });

    // Show ad as overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: VideoAdWidget(
              showSkipButton: true,
              skipDelay: const Duration(seconds: 5),
              onAdDismissed: () {
                Navigator.of(context).pop();
                setState(() {
                  _showingAd = false;
                });
              },
            ),
          ),
    );
  }

  bool _handleScrollNotification(
    ScrollNotification notification,
    ForYouFeedState feedState,
  ) {
    if (!_hasInitialized || !mounted) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (feedState.isLoading || !feedState.hasMore) return false;
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null) {
      return false;
    }

    const thresholdPages = 2.0;
    final viewport = notification.metrics.viewportDimension;
    if (viewport <= 0) return false;
    final remainingPages = notification.metrics.extentAfter / viewport;

    if (remainingPages <= thresholdPages) {
      ref.read(_forYouFeed.notifier).loadMore(
        lastViewedZapId: feedState.lastViewedZapId,
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final feedState = ref.watch(_forYouFeed);
    final zaps = feedState.zaps.reversed.toList();
    final isLoading = feedState.isLoading;

    if (zaps.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        body: SafeArea(
          top: false,
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 500,
                  child: Center(
                    child:
                        isLoading
                            ? const CircularProgressIndicator()
                            : const Text('No zaps yet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light, // ensures white icons on top
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: NotificationListener<ScrollNotification>(
              onNotification:
                  (notification) =>
                      _handleScrollNotification(notification, feedState),
              child: PageView.builder(
                key: const PageStorageKey('shortsPageView'),
                scrollDirection: Axis.vertical,
                controller: _pageController,
                itemCount: zaps.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _showingAd = false;
                  });

                  // Track last viewed zap ID
                  if (index < zaps.length) {
                    final currentZap = zaps[index];
                    ref.read(_forYouFeed.notifier).updateLastViewedZapId(currentZap.id);
                  }

                  // Check if we should show an ad after this video
                  if (_adManager.shouldShowShortsAd() &&
                      index > 0 &&
                      index < zaps.length - 1 &&
                      !_showingAd) {
                    // Show ad on next swipe
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted && _currentIndex == index) {
                        _showShortsAd();
                      }
                    });
                  }
                },
                itemBuilder: (context, index) {
                  // Check if this position should show an ad
                  if (_showingAd && index == _currentIndex) {
                    return VideoAdWidget(
                      showSkipButton: true,
                      skipDelay: const Duration(seconds: 5),
                      onAdDismissed: () {
                        setState(() {
                          _showingAd = false;
                        });
                      },
                    );
                  }

                  final zap = zaps[index];
                  return ShortVideoWidget(
                    zap: zap,
                    shouldPlay:
                        widget.isActive &&
                        index == _currentIndex &&
                        !_showingAd,
                    onControllerChange: (controller) {
                      setState(() {
                        _currentController = controller;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
