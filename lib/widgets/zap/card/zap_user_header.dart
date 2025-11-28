import 'package:flutter/material.dart';
import 'package:z/models/user_model.dart';
import 'package:z/widgets/common/profile_picture.dart';
import 'package:timeago/timeago.dart' as timeago;

class ZapUserHeader extends StatelessWidget {
  final UserModel user;
  final DateTime createdAt;
  final VoidCallback onTap;

  const ZapUserHeader({
    super.key,
    required this.user,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: ProfilePicture(
        name: user.displayName,
        pfp: user.profilePictureUrl,
      ),
      title: Row(
        children: [
          Text(
            user.displayName,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (user.isVerified) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.verified,
              size: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
          const SizedBox(width: 4),
          Text(
            '·',
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(color: Colors.blueGrey),
          ),
          const SizedBox(width: 4),
          Text(
            timeago.format(createdAt),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.blueGrey),
          ),
        ],
      ),
      subtitle: Text('@${user.username}'),
      subtitleTextStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
    );
  }
}
