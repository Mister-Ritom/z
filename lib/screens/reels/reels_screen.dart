import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:z/providers/tweet_provider.dart';
import 'package:z/widgets/video_player_widget.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  final bool isActive; // parent tells if this page is active
  const ReelsScreen({super.key, required this.isActive});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController(viewportFraction: 0.99);
  VideoPlayerController? _currentController;

  int _currentIndex = 0;
  get forYouFeed => forYouFeedProvider(true);

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onScroll);
    _onRefresh(); // Load initial data
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
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

  void _onScroll() {
    final scrollPos = _pageController.position;
    if (scrollPos.pixels >= scrollPos.maxScrollExtent - 200) {
      ref.read(forYouFeed.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(forYouFeed.notifier).loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenSize = MediaQuery.of(context).size;
    final tweets = ref.watch(forYouFeed).reversed.toList();

    if (tweets.isEmpty) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 500,
                child: Center(child: Text('No tweets yet')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: PageView.builder(
          key: const PageStorageKey('reelsPageView'),

          scrollDirection: Axis.vertical,
          controller: _pageController,
          itemCount: tweets.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final tweet = tweets[index];
            return SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: VideoPlayerWidget(
                isFile: false,
                url: tweet.mediaUrls[0],
                width: screenSize.width,
                height: screenSize.height,
                isPlaying: widget.isActive && index == _currentIndex,
                onControllerChange:
                    (controller) => setState(() {
                      _currentController = controller;
                    }),
                disableFullscreen:
                    true, // disable double-tap fullscreen for Reels
              ),
            );
          },
        ),
      ),
    );
  }
}
