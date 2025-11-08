import 'dart:developer';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CameraView extends StatefulWidget {
  final int limit;
  const CameraView({super.key, this.limit = 15});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView>
    with SingleTickerProviderStateMixin {
  late List<CameraDescription> _cameras;
  CameraController? _controller;
  bool _isRearCamera = true;
  bool _isRecording = false;
  bool _isVideo = false;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _isVideo = _tabController.index == 1;
      });
    });
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

    if (_tabController.index == 0) {
      // Photo mode
      final image = await _controller?.takePicture();
      if (image != null) {
        log("Captured photo: ${image.path}");
        if (mounted) {
          Navigator.pop(context, [image]);
        }
      }
    } else {
      // Video mode
      if (_isRecording) {
        final file = await _controller?.stopVideoRecording();
        _timer?.cancel();
        setState(() {
          _recordDuration = Duration.zero;
        });
        if (file != null) {
          log("Recorded video: ${file.path}");
          if (mounted) {
            Navigator.pop(context, [file]);
          }
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
      final List<XFile> files = await _picker.pickMultipleMedia(
        limit: widget.limit,
      );
      if (files.isNotEmpty) {
        log("picked ${files.length} files");
        if (mounted) {
          Navigator.pop(context, files);
        }
      }
    } else {
      final file = await _picker.pickMedia();
      if (file != null) {
        final files = [file!];
        log("picked ${files.length} files");
        if (mounted) {
          Navigator.pop(context, files);
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tabController.dispose();
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
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            SafeArea(child: Center(child: CameraPreview(_controller!)))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Duration timer (top right when recording)
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

          Align(
            alignment: AlignmentGeometry.bottomCenter,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Photo'), Tab(text: 'Video')],
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.photo_library_outlined,
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
                    Icons.cameraswitch_outlined,
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
