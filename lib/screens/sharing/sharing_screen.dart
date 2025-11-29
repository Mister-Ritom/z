import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/auth_provider.dart';

class SharingScreen extends ConsumerWidget {
  final List<String> mediaPaths;
  const SharingScreen(this.mediaPaths, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // use the current user ref from provider. if user is null show a message and a button to go to login
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      return Scaffold(body: Center(child: Text('You are not logged in')));
    }
    //if media is empty, show a message and button to close the screen and go back to "/"
    if (mediaPaths.isEmpty) {
      return Scaffold(body: Center(child: Text('No media to share')));
    }

    return Scaffold(body: Center(child: Text('Sharing')));
  }
}
