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
  final bool thumbnailOnly;
  final int? borderRadius;

  const MediaCarousel({
    super.key,
    required this.mediaUrls,
    this.maxHeight = 300,
    this.thumbnailOnly = false,
    this.borderRadius,
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

  double _itemHeightForIndex(int index, double screenWidth) {
    final ratio = _aspectRatios[index] ?? 16 / 9;
    final naturalHeight = screenWidth / ratio;
    return naturalHeight.clamp(120, widget.maxHeight);
  }

  double _itemWidthForIndex(int index, double height) {
    final ratio = _aspectRatios[index] ?? 16 / 9;
    return height * ratio;
  }

  double _currentHeight(double screenWidth) {
    return _itemHeightForIndex(_currentPage.round(), screenWidth);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrls.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final height = _currentHeight(screenWidth);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: SizedBox(height: height, child: _buildPageview(screenWidth)),
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

  Widget _buildPageview(double screenWidth) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.mediaUrls.length > 1)
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.mediaUrls.length, (index) {
                final isActive = _currentPage.round() == index;
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
        PageView.builder(
          controller: _pageController,
          itemCount: widget.mediaUrls.length,
          onPageChanged:
              (index) => setState(() => _currentPage = index.toDouble()),
          itemBuilder: (context, index) {
            final url = widget.mediaUrls[index];
            final isLocal = Helpers.isLocalMedia(url);

            final height = _itemHeightForIndex(index, screenWidth);
            final width = _itemWidthForIndex(index, height);

            Widget child;
            try {
              if (Helpers.isVideoPath(url)) {
                child = VideoPlayerWidget(
                  isFile: isLocal,
                  url: url,
                  width: width,
                  height: height,
                  thumbnailOnly: widget.thumbnailOnly,
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
                  width: width,
                  height: height,
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
                  width: width,
                  height: height,
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

            return Center(
              child: AnimatedScale(
                scale: index == _currentPage.round() ? 1.0 : 0.95,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      widget.borderRadius?.toDouble() ?? 0,
                    ),
                    child: SizedBox(width: width, height: height, child: child),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
