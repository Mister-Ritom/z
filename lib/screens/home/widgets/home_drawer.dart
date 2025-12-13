import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/settings_provider.dart';
import 'package:z/utils/logger.dart';
import 'package:z/widgets/common/profile_picture.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserModel = ref.watch(currentUserModelProvider).valueOrNull;
    final theme = ref.watch(settingsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color:
                  currentUserModel?.coverPhotoUrl == null
                      ? Theme.of(context).colorScheme.surface
                      : null,
              image:
                  currentUserModel?.coverPhotoUrl != null
                      ? DecorationImage(
                        image: CachedNetworkImageProvider(
                          currentUserModel!.coverPhotoUrl!,
                        ),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.5),
                          BlendMode.darken,
                        ),
                      )
                      : null,
            ),
            accountName: Text(
              currentUser?.displayName ?? 'No Name',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            accountEmail: Text(
              currentUser?.email ?? 'No Email',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            currentAccountPicture: InkWell(
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/${currentUser?.uid}');
              },
              child: ProfilePicture(
                pfp: currentUser?.photoURL,
                name: currentUser?.displayName,
              ),
            ),
          ),
          _DrawerTile(
            icon: Icons.person_outline,
            title: 'Profile',
            onTap: () {
              Navigator.pop(context);
              context.push('/profile/${currentUser?.uid}');
            },
          ),
          _DrawerTile(
            icon: Icons.bookmark_outline,
            title: 'Bookmarks',
            onTap: () {
              Navigator.pop(context);
              context.push('/bookmarks');
            },
          ),
          _DrawerTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          const Divider(),
          _DrawerTile(
            icon: Icons.feedback_outlined,
            title: 'Feedback',
            onTap: () {
              Navigator.pop(context);
              context.push('/feedback');
            },
          ),
          _DrawerTile(
            icon: Icons.article_outlined,
            title: 'Terms of Service',
            onTap: () {
              Navigator.pop(context);
              context.push('/terms');
            },
          ),
          _DrawerTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.pop(context);
              context.push('/privacy');
            },
          ),
          const Divider(),
          _DrawerTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (dContext) => AlertDialog(
                      title: const Text('Confirm Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dContext),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            try {
                              final authService = ref.read(authServiceProvider);

                              Navigator.pop(dContext);

                              Future.microtask(() async {
                                await authService.signOut();
                              });
                            } catch (e, st) {
                              AppLogger.error(
                                "Logout dialog",
                                "Failed to logout",
                                error: e,
                                stackTrace: st,
                              );
                            }
                          },

                          child: const Text('Logout'),
                        ),
                      ],
                    ),
              );
            },
          ),
          const Divider(),
          _DrawerTile(
            icon: switch (theme.theme) {
              AppTheme.light => Icons.light_mode_outlined,
              AppTheme.dark => Icons.dark_mode_outlined,
              AppTheme.system => Icons.brightness_auto_outlined,
            },
            title: switch (theme.theme) {
              AppTheme.light => 'Light',
              AppTheme.dark => 'Dark',
              AppTheme.system => 'System',
            },
            onTap: () {
              final notifier = ref.read(settingsProvider.notifier);
              final nextTheme = switch (theme.theme) {
                AppTheme.light => AppTheme.dark,
                AppTheme.dark => AppTheme.system,
                AppTheme.system => AppTheme.light,
              };
              notifier.setTheme(nextTheme);
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}
