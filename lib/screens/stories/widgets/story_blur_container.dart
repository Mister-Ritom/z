import 'dart:ui';

import 'package:flutter/material.dart';

class StoryBlurContainer extends StatelessWidget {
  final Widget child;

  const StoryBlurContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: child,
        ),
      ),
    );
  }
}
