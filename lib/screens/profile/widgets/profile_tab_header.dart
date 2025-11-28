import 'package:flutter/material.dart';

class ProfileTabHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  ProfileTabHeader({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(ProfileTabHeader oldDelegate) {
    return false;
  }
}
