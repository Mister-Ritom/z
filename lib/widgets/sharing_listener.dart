import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sharing_provider.dart';
import '../utils/router.dart';

class SharingListener extends ConsumerStatefulWidget {
  final Widget child;

  const SharingListener({super.key, required this.child});

  @override
  ConsumerState<SharingListener> createState() => _SharingListenerState();
}

class _SharingListenerState extends ConsumerState<SharingListener> {
  StreamSubscription? _sharingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSharingListener();
    });
  }

  void _setupSharingListener() {
    final sharingService = ref.read(sharingServiceProvider);
    final router = ref.read(routerProvider);
    
    _sharingSubscription = sharingService.sharedMediaStream.listen((sharedFiles) {
      if (sharedFiles.isNotEmpty && mounted) {
        router.go('/share', extra: sharedFiles);
      }
    });
  }

  @override
  void dispose() {
    _sharingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

