import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:z/models/user_model.dart';
import 'package:z/screens/messages/chat_screen.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tweet_provider.dart';
import '../../models/tweet_model.dart';
import '../../widgets/tweet_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../../utils/helpers.dart';
import 'edit_profile_screen.dart';
import '../../info/tweet/tweet_detail_screen.dart';
import 'followers_screen.dart';
import 'following_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    final isOwnProfile = currentUser?.id == widget.userId;
    final userAsync = ref.watch(userProfileProvider(widget.userId));
    final userTweetsAsync = ref.watch(userTweetsProvider(widget.userId));

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // App bar with cover photo
                SliverAppBar(
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
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            ),
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => EditProfileScreen(user: user),
                              ),
                            );
                            break;
                          case 'report':
                            // Show report dialog
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Report User'),
                                    content: const Text(
                                      'Are you sure you want to report this user?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'User reported successfully',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('Report'),
                                      ),
                                    ],
                                  ),
                            );
                            break;
                          case 'block':
                            // Show block dialog
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Block User'),
                                    content: const Text(
                                      'Are you sure you want to block this user?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'User blocked successfully',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('Block'),
                                      ),
                                    ],
                                  ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) {
                        if (isOwnProfile) {
                          return [
                            const PopupMenuItem(
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
                        } else {
                          return [
                            const PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag_outlined),
                                  SizedBox(width: 8),
                                  Text('Report'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
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
                        }
                      },
                    ),
                  ],
                ),
                // Profile info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile picture and edit button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage:
                                      user.profilePictureUrl != null
                                          ? CachedNetworkImageProvider(
                                            user.profilePictureUrl!,
                                          )
                                          : null,
                                  child:
                                      user.profilePictureUrl == null
                                          ? Text(
                                            user.displayName[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 40,
                                            ),
                                          )
                                          : null,
                                ),
                                if (isOwnProfile)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => EditProfileScreen(
                                                  user: user,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                            if (!isOwnProfile && currentUser != null)
                              SizedBox(
                                width: 120,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _followButton(currentUser.id, user.id),
                                    SizedBox(height: 12),
                                    _messageButton(currentUser.id, user),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        // User info
                        Row(
                          children: [
                            Text(
                              user.displayName,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            if (user.isVerified) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.verified,
                                size: 24,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (user.bio != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            user.bio!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Stats
                        Row(
                          children: [
                            _buildStat(
                              context,
                              'Following',
                              user.followingCount,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => FollowingScreen(
                                          userId: widget.userId,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 24),
                            _buildStat(
                              context,
                              'Followers',
                              user.followersCount,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => FollowersScreen(
                                          userId: widget.userId,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 24),
                            _buildStat(context, 'Tweets', user.tweetsCount),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Tabs
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Tweets'),
                        Tab(text: 'Replies'),
                        Tab(text: 'Media'),
                        Tab(text: 'Likes'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tweets tab (includes original tweets and retweets)
                Consumer(
                  builder: (context, ref, child) {
                    final tweetsAsync = ref.watch(
                      userTweetsProvider(widget.userId),
                    );
                    final retweetsAsync = ref.watch(
                      userRetweetedTweetsProvider(widget.userId),
                    );

                    return tweetsAsync.when(
                      data: (originalTweets) {
                        return retweetsAsync.when(
                          data: (retweetedTweets) {
                            // Combine original tweets and retweets
                            final allTweets = <TweetModel>[
                              ...originalTweets,
                              ...retweetedTweets,
                            ];
                            // Sort by createdAt descending
                            allTweets.sort(
                              (a, b) => b.createdAt.compareTo(a.createdAt),
                            );

                            if (allTweets.isEmpty) {
                              return const Center(child: Text('No tweets yet'));
                            }

                            return ListView.builder(
                              itemCount: allTweets.length,
                              itemBuilder: (context, index) {
                                final tweet = allTweets[index];
                                final isRetweet = retweetedTweets.any(
                                  (t) => t.id == tweet.id,
                                );
                                // Get the original author for retweeted tweets
                                final tweetUserAsync =
                                    isRetweet
                                        ? ref.watch(
                                          userProfileProvider(tweet.userId),
                                        )
                                        : AsyncValue.data(user);

                                return tweetUserAsync.when(
                                  data:
                                      (tweetUser) => TweetCard(
                                        tweet: tweet,
                                        user: tweetUser ?? user,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      TweetDetailScreen(
                                                        tweetId: tweet.id,
                                                      ),
                                            ),
                                          );
                                        },
                                        onUserTap: () {
                                          if (tweetUser != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => ProfileScreen(
                                                      userId: tweetUser.id,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                  loading: () => const TweetCardShimmer(),
                                  error: (_, __) => const SizedBox.shrink(),
                                );
                              },
                            );
                          },
                          loading:
                              () => ListView.builder(
                                itemCount: 5,
                                itemBuilder:
                                    (context, index) =>
                                        const TweetCardShimmer(),
                              ),
                          error: (error, stack) {
                            log("Error: $error", stackTrace: stack);
                            return Center(child: Text('Error: $error'));
                          },
                        );
                      },
                      loading:
                          () => ListView.builder(
                            itemCount: 5,
                            itemBuilder:
                                (context, index) => const TweetCardShimmer(),
                          ),
                      error: (error, stack) {
                        log("Error: $error");
                        return Center(child: Text('Error: $error'));
                      },
                    );
                  },
                ),
                // Replies tab (showing replies only)
                ref
                    .watch(userRepliesProvider(widget.userId))
                    .when(
                      data: (replies) {
                        if (replies.isEmpty) {
                          return const Center(child: Text('No replies yet'));
                        }

                        return ListView.builder(
                          itemCount: replies.length,
                          itemBuilder: (context, index) {
                            final tweet = replies[index];
                            return TweetCard(
                              tweet: tweet,
                              user: user,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => TweetDetailScreen(
                                          tweetId: tweet.id,
                                        ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      loading:
                          () => ListView.builder(
                            itemCount: 5,
                            itemBuilder:
                                (context, index) => const TweetCardShimmer(),
                          ),
                      error: (error, stack) {
                        log("Error: $error");
                        return Center(child: Text('Error: $error'));
                      },
                    ),
                // Media tab (showing tweets with media)
                userTweetsAsync.when(
                  data: (tweets) {
                    // Filter tweets with media
                    final mediaTweets =
                        tweets
                            .where((tweet) => tweet.mediaUrls.isNotEmpty)
                            .toList();
                    if (mediaTweets.isEmpty) {
                      return const Center(child: Text('No media yet'));
                    }

                    return ListView.builder(
                      itemCount: mediaTweets.length,
                      itemBuilder: (context, index) {
                        final tweet = mediaTweets[index];
                        return TweetCard(
                          tweet: tweet,
                          user: user,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        TweetDetailScreen(tweetId: tweet.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  loading:
                      () => ListView.builder(
                        itemCount: 5,
                        itemBuilder:
                            (context, index) => const TweetCardShimmer(),
                      ),
                  error: (error, stack) {
                    log("Error: $error");
                    return Center(child: Text('Error: $error'));
                  },
                ),
                // Likes tab
                ref
                    .watch(userLikedTweetsProvider(widget.userId))
                    .when(
                      data: (likedTweets) {
                        if (likedTweets.isEmpty) {
                          return const Center(
                            child: Text('No liked tweets yet'),
                          );
                        }

                        return ListView.builder(
                          itemCount: likedTweets.length,
                          itemBuilder: (context, index) {
                            final tweet = likedTweets[index];
                            final tweetUserAsync = ref.watch(
                              userProfileProvider(tweet.userId),
                            );

                            return tweetUserAsync.when(
                              data: (tweetUser) {
                                if (tweetUser == null) {
                                  return Text("User not found");
                                }
                                return TweetCard(
                                  tweet: tweet,
                                  user: tweetUser,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => TweetDetailScreen(
                                              tweetId: tweet.id,
                                            ),
                                      ),
                                    );
                                  },
                                  onUserTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ProfileScreen(
                                              userId: tweetUser.id,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () => const TweetCardShimmer(),
                              error: (_, __) => const SizedBox.shrink(),
                            );
                          },
                        );
                      },
                      loading:
                          () => ListView.builder(
                            itemCount: 5,
                            itemBuilder:
                                (context, index) => const TweetCardShimmer(),
                          ),
                      error: (error, stack) {
                        log("Error: $error");
                        return Center(child: Text('Error: $error'));
                      },
                    ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          log("Error: $error");
          return Center(child: Text('Error: $error'));
        },
      ),
    );
  }

  Widget _followButton(String currentUserId, String userId) {
    final profileService = ref.read(profileServiceProvider);

    return FutureBuilder<bool>(
      future: profileService.isFollowing(currentUserId, userId),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                isLoading
                    ? null
                    : () async {
                      if (isFollowing) {
                        await profileService.unfollowUser(
                          currentUserId,
                          userId,
                        );
                      } else {
                        await profileService.followUser(currentUserId, userId);
                      }

                      // Trigger rebuild after following/unfollowing
                      (context as Element).markNeedsBuild();
                    },
            child:
                isLoading
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(isFollowing ? 'Unfollow' : 'Follow'),
          ),
        );
      },
    );
  }

  Widget _messageButton(String currentUserId, UserModel user) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ChatScreen(
                    currentUserId: currentUserId,
                    otherUserId: user.id,
                    otherUser: user,
                  ),
            ),
          );
        },
        child: Text("Message"),
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    String label,
    int count, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Helpers.formatNumber(count),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => child.preferredSize.height;

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
