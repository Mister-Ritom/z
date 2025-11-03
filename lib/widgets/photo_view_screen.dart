import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class PhotoViewScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const PhotoViewScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1}/${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PhotoViewGallery.builder(
        pageController: _controller,
        itemCount: widget.images.length,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.images[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        loadingBuilder:
            (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
      ),
    );
  }
}
