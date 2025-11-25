import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'package:image_picker/image_picker.dart';

class SharingService {
  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  
  final _sharedMediaController = StreamController<List<SharedMediaFile>>.broadcast();
  
  Stream<List<SharedMediaFile>> get sharedMediaStream => _sharedMediaController.stream;
  
  void initialize() {
    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      _sharedMediaController.add(value);
    }, onError: (err) {
      log("getIntentDataStream error: $err");
    });

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _sharedMediaController.add(value);
      }
    });
  }
  
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _sharedMediaController.close();
  }
  
  /// Convert SharedMediaFile to XFile
  Future<List<XFile>> convertToXFiles(List<SharedMediaFile> sharedFiles) async {
    final xFiles = <XFile>[];
    
    for (final sharedFile in sharedFiles) {
      final path = sharedFile.path;
      final file = File(path);
      if (await file.exists()) {
        xFiles.add(XFile(path));
      }
    }
    
    return xFiles;
  }
  
  /// Check if shared media contains only a single video
  bool isSingleVideo(List<SharedMediaFile> sharedFiles) {
    if (sharedFiles.length != 1) return false;
    final file = sharedFiles.first;
    return file.type == SharedMediaType.video;
  }
  
  /// Check if shared media contains only images
  bool isOnlyImages(List<SharedMediaFile> sharedFiles) {
    return sharedFiles.isNotEmpty && 
           sharedFiles.every((file) => file.type == SharedMediaType.image);
  }
  
  /// Check if shared media contains videos
  bool hasVideos(List<SharedMediaFile> sharedFiles) {
    return sharedFiles.any((file) => file.type == SharedMediaType.video);
  }
}

