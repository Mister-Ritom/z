import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
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
  final void Function(double aspectRatio)? onAspectRatioCalculated;

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
    this.onAspectRatioCalculated,
  });

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
    void Function(double aspectRatio)? onAspectRatioCalculated,
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
      onAspectRatioCalculated: onAspectRatioCalculated,
    );
  }

  factory AppImage.network(
    String url, {
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
    void Function(double aspectRatio)? onAspectRatioCalculated,
  }) {
    return AppImage._(
      key: key,
      imageProvider: CachedNetworkImageProvider(url),
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
      onAspectRatioCalculated: onAspectRatioCalculated,
    );
  }

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
    void Function(double aspectRatio)? onAspectRatioCalculated,
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
      onAspectRatioCalculated: onAspectRatioCalculated,
    );
  }

  static Widget xFile(
    XFile file, {
    Key? key,
    BoxFit? fit,
    double? width,
    double? height,
    Alignment alignment = Alignment.center,
    Color? color,
    BlendMode? colorBlendMode,
    FilterQuality filterQuality = FilterQuality.low,
    VoidCallback? onDoubleTap,
    void Function(double aspectRatio)? onAspectRatioCalculated,
  }) {
    return FutureBuilder<ImageProvider>(
      future: _loadImageProvider(file),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return const Icon(Icons.error, color: Colors.red);
        }
        return AppImage._(
          key: key,
          imageProvider: snapshot.data!,
          fit: fit,
          width: width,
          height: height,
          alignment: alignment,
          color: color,
          colorBlendMode: colorBlendMode,
          filterQuality: filterQuality,
          onDoubleTap: onDoubleTap,
          onAspectRatioCalculated: onAspectRatioCalculated,
        );
      },
    );
  }

  static Future<ImageProvider> _loadImageProvider(XFile file) async {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return MemoryImage(bytes);
    } else {
      return FileImage(File(file.path));
    }
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

  void _calculateAspectRatio() {
    final imageStream = imageProvider.resolve(const ImageConfiguration());
    imageStream.addListener(
      ImageStreamListener((info, _) {
        final width = info.image.width;
        final height = info.image.height;
        if (height != 0) {
          onAspectRatioCalculated?.call(width / height);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    _calculateAspectRatio();

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
