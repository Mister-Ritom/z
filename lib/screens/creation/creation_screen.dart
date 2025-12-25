import 'dart:ui';

import 'package:cooler_ui/cooler_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:z/screens/creation/abstract_page.dart';
import 'package:z/screens/creation/post_creation.dart';
import 'package:z/screens/creation/shorts_creation.dart';
import 'package:z/screens/creation/story_creation.dart';

class CreationScreen extends ConsumerStatefulWidget {
  final List<XFile>? initialMedia;
  const CreationScreen({super.key, this.initialMedia});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _CreationScreenState();
  }
}

class _CreationScreenState extends ConsumerState<CreationScreen> {
  final indexProvider = StateProvider((ref) => 0);

  final _postKey = GlobalKey<PostCreationState>();
  final _storyKey = GlobalKey<StoryCreationState>();
  final _shortsKey = GlobalKey<ShortsCreationState>();

  late final List<Widget> _pages = [
    PostCreation(key: _postKey),
    StoryCreation(key: _storyKey),
    ShortsCreation(key: _shortsKey),
  ];

  CreationPage? get _currentStep {
    final index = ref.read(indexProvider);
    return switch (index) {
      0 => _postKey.currentState,
      1 => _storyKey.currentState,
      2 => _shortsKey.currentState,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = ref.watch(indexProvider);

    return CoolScaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(LucideIcons.chevronLeft),
        ),
        title: Text("Create New"),
        actions: [
          CoolButton(
            variant: CoolButtonVariant.text,
            onPressed: () async {
              final result = await _currentStep?.onNext();

              if (result == CreationResult.success && context.mounted) {
                Navigator.pop(context);
              }
            },
            text: "Next",
          ),
        ],
      ),
      body: CoolStack(
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _pages[pageIndex],
          ),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10)),
          Align(
            alignment: Alignment.bottomCenter,
            child: CoolHorizontalSliderSelector(
              items: const [
                HorizontalSelectionItem(title: "Post"),
                HorizontalSelectionItem(title: "Story"),
                HorizontalSelectionItem(title: "Shorts"),
              ],
              onSelect: (index, _) {
                if (pageIndex == index) return;
                ref.read(indexProvider.notifier).state = index;
              },
            ),
          ),
        ],
      ),
    );
  }
}
