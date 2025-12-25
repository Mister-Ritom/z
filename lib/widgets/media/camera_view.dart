import 'dart:developer';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum CameraMode { photo, video, both }

class CameraView extends StatefulWidget {
  final int limit;
  final bool require;
  final String title;
  final CameraMode mode;

  const CameraView({
    super.key,
    this.limit = 15,
    this.require = true,
    this.title = "Camera",
    this.mode = CameraMode.both,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late List<CameraDescription> _cameras;
  CameraController? _controller;
  bool _isRearCamera = true;
  bool _isRecording = false;
  bool _isVideo = false;
  final ImagePicker _picker = ImagePicker();
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  late final List<HorizontalSelectionItem> _items;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    _items = switch (widget.mode) {
      CameraMode.photo => const [HorizontalSelectionItem(title: "Photo")],
      CameraMode.video => const [HorizontalSelectionItem(title: "Video")],
      CameraMode.both => const [
        HorizontalSelectionItem(title: "Photo"),
        HorizontalSelectionItem(title: "Video"),
      ],
    };

    _isVideo = widget.mode == CameraMode.video;

    _initCamera();
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    try {
      final cameras = await availableCameras();
      _cameras = cameras;

      final selected =
          _isRearCamera
              ? _cameras.firstWhere(
                (c) => c.lensDirection == CameraLensDirection.back,
                orElse: () => _cameras.first,
              )
              : _cameras.firstWhere(
                (c) => c.lensDirection == CameraLensDirection.front,
                orElse: () => _cameras.first,
              );

      final newController = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await newController.initialize();

      if (!mounted) return;

      setState(() {
        _controller = newController;
      });
    } catch (e) {
      log("Error camera", error: e);
    }
  }

  Future<void> _switchCamera() async {
    if (_controller == null) return;

    final oldController = _controller;

    setState(() {
      _controller = null;
    });

    await oldController?.dispose();

    _isRearCamera = !_isRearCamera;
    await _initCamera();
  }

  Future<void> _capture() async {
    HapticFeedback.mediumImpact();

    if (!_isVideo) {
      final image = await _controller?.takePicture();
      if (image != null && mounted) {
        log("Captured photo: ${image.path}");
        Navigator.pop(context, [image]);
      }
    } else {
      if (_isRecording) {
        final file = await _controller?.stopVideoRecording();
        _timer?.cancel();
        setState(() {
          _recordDuration = Duration.zero;
        });
        if (file != null && mounted) {
          log("Recorded video: ${file.path}");
          Navigator.pop(context, [file]);
        }
      } else {
        await _controller?.startVideoRecording();
        _startTimer();
      }
      setState(() => _isRecording = !_isRecording);
    }
  }

  void _startTimer() {
    _recordDuration = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
  }

  Future<void> _pickMedia() async {
    if (widget.limit > 1) {
      List<XFile> files = [];

      switch (widget.mode) {
        case CameraMode.photo:
          files = await _picker.pickMultiImage(limit: widget.limit);
          break;
        case CameraMode.video:
          files = await _picker.pickMultiVideo(limit: widget.limit);
          break;
        case CameraMode.both:
          files = await _picker.pickMultipleMedia(limit: widget.limit);
          break;
      }

      if (files.isNotEmpty && mounted) {
        Navigator.pop(context, files);
      }
    } else {
      XFile? file;

      switch (widget.mode) {
        case CameraMode.photo:
          file = await _picker.pickImage(source: ImageSource.gallery);
          break;
        case CameraMode.video:
          file = await _picker.pickVideo(source: ImageSource.gallery);
          break;
        case CameraMode.both:
          file = await _picker.pickMedia();
          break;
      }

      if (mounted) {
        file == null ? Navigator.pop(context) : Navigator.pop(context, [file]);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading:
            widget.require
                ? const SizedBox.shrink()
                : IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
        title: Text(widget.title),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            SafeArea(child: Center(child: CameraPreview(_controller!)))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          if (_isRecording)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_items.length > 1)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 180,
                  child: CoolHorizontalSliderSelector(
                    items: _items,
                    onSelect: (index, item) {
                      if (_selectedIndex == index) return;
                      setState(() {
                        _selectedIndex = index;
                        _isVideo = item.title == "Video";
                      });
                    },
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    LucideIcons.fileImage,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _pickMedia,
                ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isVideo ? Colors.red : Colors.white,
                      border:
                          _isVideo
                              ? Border.all(
                                color:
                                    _isRecording ? Colors.green : Colors.white,
                                width: 4,
                              )
                              : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.refreshCcw,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
