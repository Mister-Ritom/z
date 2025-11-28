import 'package:flutter/material.dart';

class StoryCaption extends StatelessWidget {
  final String caption;
  final Widget Function(Widget child) backgroundBuilder;

  const StoryCaption({
    super.key,
    required this.caption,
    required this.backgroundBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (caption.isEmpty) return const SizedBox.shrink();
    return backgroundBuilder(
      Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text(
          caption,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
