import 'package:flutter/material.dart';
import 'package:z/models/story_model.dart';

class StoryProgressBars extends StatelessWidget {
  final List<StoryModel> stories;
  final int currentIndex;
  final double progress;

  const StoryProgressBars({
    super.key,
    required this.stories,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          stories.asMap().entries.map((entry) {
            final index = entry.key;
            final value =
                index < currentIndex
                    ? 1.0
                    : index == currentIndex
                    ? progress
                    : 0.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 2,
                ),
              ),
            );
          }).toList(),
    );
  }
}
