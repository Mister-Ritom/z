import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:z/models/story_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/widgets/common/profile_picture.dart';
import 'package:z/widgets/stories/story_options_sheet.dart';

class StoryUserInfo extends StatelessWidget {
  final UserModel user;
  final StoryModel story;
  final VoidCallback onBack;
  final Widget Function(Widget child) backgroundBuilder;
  final VoidCallback? onDeleted;

  const StoryUserInfo({
    super.key,
    required this.user,
    required this.story,
    required this.onBack,
    required this.backgroundBuilder,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return backgroundBuilder(
      Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          ProfilePicture(pfp: user.profilePictureUrl, name: user.displayName),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              Text(
                timeago.format(story.createdAt),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => StoryOptionsSheet(
                  story: story,
                  onDeleted: onDeleted,
                ),
              );
            },
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
