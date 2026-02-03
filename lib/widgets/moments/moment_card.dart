import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/models/moment_model.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class MomentCard extends ConsumerWidget {
  final MomentModel moment;

  const MomentCard({super.key, required this.moment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(moment.userId));
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 150, // Slightly wider
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Icon + User Avatar (mini)
          Row(
            children: [
              _CategoryIcon(category: moment.category),
              const Spacer(),
              userAsync.when(
                data:
                    (user) => Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.secondary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            user?.profilePictureUrl != null
                                ? NetworkImage(user!.profilePictureUrl!)
                                : null,
                        child:
                            user?.profilePictureUrl == null
                                ? Icon(
                                  Icons.person,
                                  size: 8,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                )
                                : null,
                      ),
                    ),
                loading: () => const SizedBox(width: 16, height: 16),
                error: (_, __) => const SizedBox(width: 16, height: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          Text(
            moment.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          // Footer: Time
          Text(
            timeago.format(moment.createdAt, locale: 'en_short'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final MomentCategory category;

  const _CategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (category) {
      case MomentCategory.life:
        icon = Icons.spa_outlined;
        color = Colors.green;
        break;
      case MomentCategory.habit:
        icon = Icons.check_circle_outline;
        color = Colors.blue;
        break;
      case MomentCategory.mood:
        icon = Icons.mood;
        color = Colors.orange;
        break;
      case MomentCategory.presence:
        icon = Icons.location_on_outlined;
        color = Colors.purple;
        break;
      case MomentCategory.reflection:
        icon = Icons.lightbulb_outline;
        color = Colors.amber;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }
}
