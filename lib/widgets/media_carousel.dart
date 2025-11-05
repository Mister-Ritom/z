import 'package:flutter/material.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/widgets/app_image.dart';
import 'package:z/widgets/photo_view_screen.dart';
import 'package:z/widgets/video_player_widget.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> mediaUrls;
  final bool Function(String s) isVideo;
  const MediaCarousel({
    super.key,
    required this.mediaUrls,
    required this.isVideo,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  late final PageController _pageController;
  double _currentPage = 0;

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

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrls.isEmpty) {
      return SizedBox.shrink();
    } else if (widget.mediaUrls.length == 1 &&
        widget.isVideo(widget.mediaUrls[0]) &&
        Helpers.isGlassSupported) {
      //Glasss support is used to check if its desktop
      return VideoPlayerWidget(isFile: false, url: widget.mediaUrls[0]);
    } else {
      return SizedBox(height: 200, child: _buildPageview());
    }
  }

  Widget _buildPageview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width,
          child: PageView(
            controller: _pageController,
            children:
                widget.mediaUrls.map((url) {
                  if (widget.isVideo(url)) {
                    return VideoPlayerWidget(
                      isFile: false,
                      url: url,
                      width: MediaQuery.of(context).size.width,
                      height: 200,
                    );
                  } else {
                    return AppImage.network(
                      url,
                      onDoubleTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => PhotoViewScreen(
                                  images: widget.mediaUrls,
                                  initialIndex: _currentPage.toInt(),
                                ),
                          ),
                        );
                      },
                    );
                  }
                }).toList(),
          ),
        ),
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
