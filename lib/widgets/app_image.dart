import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

class AppImage extends StatelessWidget {
  final ImageProvider imageProvider;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final VoidCallback? onDoubleTap;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImage._({
    super.key,
    required this.imageProvider,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.low,
    this.onDoubleTap,
    this.placeholder,
    this.errorWidget,
  });

  /// For local assets
  factory AppImage.asset(
    String path, {
    Key? key,
    BoxFit? fit,
    double? width,
    double? height,
    Alignment alignment = Alignment.center,
    Color? color,
    BlendMode? colorBlendMode,
    FilterQuality filterQuality = FilterQuality.low,
    VoidCallback? onDoubleTap,
  }) {
    return AppImage._(
      key: key,
      imageProvider: AssetImage(path),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      onDoubleTap: onDoubleTap,
    );
  }

  /// For network images — uses CachedNetworkImage internally
  factory AppImage.network({
    required String imageUrl,
    Key? key,
    BoxFit? fit,
    double? width,
    double? height,
    Alignment alignment = Alignment.center,
    Color? color,
    BlendMode? colorBlendMode,
    FilterQuality filterQuality = FilterQuality.low,
    VoidCallback? onDoubleTap,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return AppImage._(
      key: key,
      imageProvider: CachedNetworkImageProvider(imageUrl),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      onDoubleTap: onDoubleTap,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// For file-based images
  factory AppImage.file(
    File file, {
    Key? key,
    BoxFit? fit,
    double? width,
    double? height,
    Alignment alignment = Alignment.center,
    Color? color,
    BlendMode? colorBlendMode,
    FilterQuality filterQuality = FilterQuality.low,
    VoidCallback? onDoubleTap,
  }) {
    return AppImage._(
      key: key,
      imageProvider: FileImage(file),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      onDoubleTap: onDoubleTap,
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Center(
                child: PhotoView(
                  imageProvider: imageProvider,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.5,
                  heroAttributes: const PhotoViewHeroAttributes(
                    tag: 'fullscreen-image',
                  ),
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget displayWidget;

    if (imageProvider is CachedNetworkImageProvider) {
      displayWidget = CachedNetworkImage(
        imageUrl: (imageProvider as CachedNetworkImageProvider).url,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        filterQuality: filterQuality,
        placeholder:
            (context, _) =>
                placeholder ?? const Center(child: CircularProgressIndicator()),
        errorWidget:
            (context, _, __) => errorWidget ?? const Icon(Icons.broken_image),
      );
    } else {
      displayWidget = Image(
        image: imageProvider,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        filterQuality: filterQuality,
      );
    }

    return GestureDetector(
      onDoubleTap: onDoubleTap ?? () => _openFullScreen(context),
      child: displayWidget,
    );
  }
}
