import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:z/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable push notifications'),
            value: settings.enablePushNotifications,
            onChanged: notifier.setPushNotifications,
          ),
          SwitchListTile(
            title: const Text('Autoplay videos'),
            value: settings.autoplayVideos,
            onChanged: notifier.setAutoplayVideos,
          ),
          SwitchListTile(
            title: const Text('Enable glass morphism'),
            value: settings.glassMorphismEnabled,
            onChanged: notifier.setGlassMorphismEnabled,
          ),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<AppTheme>(
              value: settings.theme,
              onChanged: (value) {
                notifier.setTheme(value ?? AppTheme.system);
              },
              items: const [
                DropdownMenuItem(value: AppTheme.light, child: Text('Light')),
                DropdownMenuItem(value: AppTheme.dark, child: Text('Dark')),
                DropdownMenuItem(value: AppTheme.system, child: Text('System')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
