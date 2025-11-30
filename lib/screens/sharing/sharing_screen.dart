import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/utils/helpers.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/media/media_carousel.dart';
import 'package:z/widgets/sharing/share_action_button.dart';
import 'package:z/widgets/zap/composer/zap_composer.dart';
import 'package:z/screens/stories/story_creation_screen.dart';
import 'package:z/screens/messages/messages_screen.dart';

class SharingScreen extends ConsumerStatefulWidget {
  final List<String> mediaPaths;
  const SharingScreen(this.mediaPaths, {super.key});

  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen> {
  List<String> _mediaPaths = [];
  StreamSubscription? _intentSub;
  bool _isCheckingInitialMedia = true;

  @override
  void initState() {
    super.initState();
    _mediaPaths = widget.mediaPaths;
    // If we already have media paths, we don't need to wait for initial check
    if (_mediaPaths.isNotEmpty) {
      _isCheckingInitialMedia = false;
    }
    _initSharingIntent();
  }

  void _initSharingIntent() {
    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        _handleSharing(value);
      },
      onError: (err) {
        AppLogger.error(
          'SharingScreen',
          'Error initializing sharing intent',
          error: err,
        );
      },
    );

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((value) {
          _handleSharing(value);
          setState(() {
            _isCheckingInitialMedia = false;
          });
        })
        .catchError((err) {
          AppLogger.error(
            'SharingScreen',
            'Error getting initial media',
            error: err,
          );
          setState(() {
            _isCheckingInitialMedia = false;
          });
        });
  }

  void _handleSharing(List<SharedMediaFile> value) {
    if (value.isEmpty) {
      AppLogger.warn('SharingScreen', 'No media shared');
      // Only update state if we don't already have media paths
      if (_mediaPaths.isEmpty) {
        setState(() {
          _isCheckingInitialMedia = false;
        });
      }
      return;
    }
    final mediaPaths = value.map((e) => e.path).toList();
    AppLogger.info(
      'SharingScreen',
      'Sharing media',
      data: {'mediaPaths': mediaPaths},
    );
    setState(() {
      _mediaPaths = mediaPaths;
      _isCheckingInitialMedia = false;
    });
  }

  List<XFile> _convertPathsToXFiles(List<String> paths) {
    return paths.map((path) {
      // Remove file:// prefix if present
      final cleanPath = path.startsWith('file://') ? path.substring(7) : path;
      return XFile(cleanPath);
    }).toList();
  }

  void _navigateToZap() {
    final files = _convertPathsToXFiles(_mediaPaths);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ZapComposer(initialMedia: files)),
    );
  }

  void _navigateToShort() {
    if (_mediaPaths.length != 1) return;
    final path = _mediaPaths.first;
    if (!Helpers.isVideoPath(path)) return;

    final files = _convertPathsToXFiles(_mediaPaths);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ZapComposer(initialMedia: files, initialIsShort: true),
      ),
    );
  }

  void _navigateToStory() {
    if (_mediaPaths.isEmpty) return;
    // Story only supports single file, take the first one
    final path = _mediaPaths.first;
    final cleanPath = path.startsWith('file://') ? path.substring(7) : path;
    final file = XFile(cleanPath);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryCreationScreen(initialFile: file),
      ),
    );
  }

  void _navigateToMessage() {
    // Navigate to messages screen with initial media
    // User will select a conversation, then media will be passed to ChatScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessagesScreen(initialMediaPaths: _mediaPaths),
      ),
    );
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // use the current user ref from provider. if user is null show a message and a button to go to login
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('You are not logged in'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }
    // Show loading while checking for initial media
    if (_isCheckingInitialMedia) {
      return Scaffold(
        appBar: AppBar(title: Text('Sharing')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    //if media is empty, show a message and button to close the screen and go back to "/"
    if (_mediaPaths.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Sharing')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('No media to share'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }
    final isSingleVideo =
        _mediaPaths.length == 1 && Helpers.isVideoPath(_mediaPaths.first);

    return Scaffold(
      appBar: AppBar(title: Text('Sharing')),
      body: Column(
        children: [
          Expanded(
            child: MediaCarousel(mediaUrls: _mediaPaths, maxHeight: 700),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ShareActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Zap',
                  onPressed: _navigateToZap,
                ),
                const SizedBox(width: 8),
                ShareActionButton(
                  icon: Icons.auto_stories_outlined,
                  label: 'Story',
                  onPressed: _navigateToStory,
                ),
                if (isSingleVideo) ...[
                  const SizedBox(width: 8),
                  ShareActionButton(
                    icon: Icons.video_library_outlined,
                    label: 'Short',
                    onPressed: _navigateToShort,
                  ),
                ],
                const SizedBox(width: 8),
                ShareActionButton(
                  icon: Icons.send_rounded,
                  label: 'Message',
                  onPressed: _navigateToMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
