import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:z/models/user_model.dart';

class ProfileAppBar extends StatelessWidget {
  final UserModel user;
  final bool isOwnProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onReportUser;
  final VoidCallback onBlockUser;

  const ProfileAppBar({
    super.key,
    required this.user,
    required this.isOwnProfile,
    required this.onEditProfile,
    required this.onReportUser,
    required this.onBlockUser,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      floating: false,
      flexibleSpace: FlexibleSpaceBar(
        background:
            user.coverPhotoUrl != null
                ? CachedNetworkImage(
                  imageUrl: user.coverPhotoUrl!,
                  fit: BoxFit.cover,
                )
                : Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEditProfile();
                break;
              case 'report':
                onReportUser();
                break;
              case 'block':
                onBlockUser();
                break;
            }
          },
          itemBuilder: (context) {
            if (isOwnProfile) {
              return const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
              ];
            }
            return const [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block),
                    SizedBox(width: 8),
                    Text('Block'),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}
