import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/common/app_image.dart';
import 'package:z/widgets/media/photo_view_screen.dart';
import 'package:z/widgets/media/video_player_widget.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> mediaUrls;
  final double maxHeight;

  const MediaCarousel({
    super.key,
    required this.mediaUrls,
    this.maxHeight = 700,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  late final PageController _pageController;
  double _currentPage = 0;
  final Map<int, double> _aspectRatios = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _getItemWidth(double screenWidth) {
    final showMultiple = screenWidth > 700;
    final visiblePages = showMultiple ? (screenWidth ~/ 300).clamp(1, 4) : 1;
    return screenWidth / visiblePages;
  }

  double _currentHeight(double screenWidth) {
    final index = _currentPage.round();
    final itemWidth = _getItemWidth(screenWidth);
    final ratio = _aspectRatios[index] ?? 16 / 9;
    return (itemWidth / ratio).clamp(100, widget.maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrls.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final height = _currentHeight(screenWidth);
    final itemWidth = _getItemWidth(screenWidth);

    return SizedBox(
      height: height,
      child: _buildPageview(screenWidth, itemWidth),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_rounded,
        size: 48,
        color: Colors.white54,
      ),
    );
  }

  Widget _buildPageview(double screenWidth, double itemWidth) {
    final showMultiple = screenWidth > 700;
    final visiblePages = showMultiple ? (screenWidth ~/ 300).clamp(1, 4) : 1;
    final viewportFraction = 1 / visiblePages;

    return Stack(
      alignment: Alignment.center,
      children: [
        PageView.builder(
          controller:
              viewportFraction == 1
                  ? _pageController
                  : PageController(viewportFraction: viewportFraction),
          itemCount: widget.mediaUrls.length,
          onPageChanged:
              (index) => setState(() => _currentPage = index.toDouble()),
          itemBuilder: (context, index) {
            final url = widget.mediaUrls[index];
            final isLocal = Helpers.isLocalMedia(url);
            final ratio = _aspectRatios[index] ?? 16 / 9;
            final itemHeight = (itemWidth / ratio).clamp(100, widget.maxHeight);

            Widget child;
            try {
              if (Helpers.isVideoPath(url)) {
                child = VideoPlayerWidget(
                  isFile: isLocal,
                  url: url,
                  width: itemWidth,
                  height: itemHeight.toDouble(),
                  onAspectRatioCalculated: (ratio) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _aspectRatios[index] = ratio);
                      }
                    });
                  },
                );
              } else if (isLocal) {
                final file = File(url);
                if (!file.existsSync()) throw Exception('Local file missing');
                child = AppImage.file(
                  file,
                  width: itemWidth,
                  height: itemHeight.toDouble(),
                  onAspectRatioCalculated: (ratio) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _aspectRatios[index] = ratio);
                      }
                    });
                  },
                  onDoubleTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PhotoViewScreen(
                              images:
                                  widget.mediaUrls
                                      .where((s) => !Helpers.isVideoPath(s))
                                      .toList(),
                              initialIndex: index,
                            ),
                      ),
                    );
                  },
                );
              } else {
                child = AppImage.network(
                  url,
                  width: itemWidth,
                  height: itemHeight.toDouble(),
                  onAspectRatioCalculated: (ratio) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _aspectRatios[index] = ratio);
                      }
                    });
                  },
                  onDoubleTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PhotoViewScreen(
                              images:
                                  widget.mediaUrls
                                      .where((s) => !Helpers.isVideoPath(s))
                                      .toList(),
                              initialIndex: index,
                            ),
                      ),
                    );
                  },
                );
              }
            } catch (e, st) {
              log('Media load error at index $index: $e', stackTrace: st);
              child = _errorPlaceholder();
            }

            return AnimatedScale(
              scale: index == _currentPage.round() ? 1.0 : 0.95,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: child,
                ),
              ),
            );
          },
        ),
        if (viewportFraction == 1 && widget.mediaUrls.length > 1)
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.mediaUrls.length, (index) {
                final isActive = (_currentPage.round() == index);
                return InkWell(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
