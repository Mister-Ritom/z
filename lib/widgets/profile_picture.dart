import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProfilePicture extends StatelessWidget {
  final String? pfp;
  final String? name;

  const ProfilePicture({super.key, this.pfp, this.name});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundImage: pfp != null ? CachedNetworkImageProvider(pfp!) : null,
      child: pfp == null ? Text(name?[0].toUpperCase() ?? "❗") : null,
    );
  }
}
