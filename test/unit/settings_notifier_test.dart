import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:z/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsNotifier', () {
    late SharedPreferences prefs;
    late SettingsNotifier notifier;

    Future<void> initializeNotifier() async {
      notifier = SettingsNotifier(preferences: prefs);
      await notifier.initialized;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await initializeNotifier();
    });

    test('loads default settings when no preferences stored', () async {
      expect(notifier.state.enablePushNotifications, isTrue);
      expect(notifier.state.autoplayVideos, isTrue);
      expect(notifier.state.theme, AppTheme.system);
    });

    test('persists push notification toggle', () async {
      await notifier.setPushNotifications(false);
      expect(notifier.state.enablePushNotifications, isFalse);
      expect(prefs.getBool('settings.push_enabled'), isFalse);
    });

    test('updates and persists theme selection', () async {
      await notifier.setTheme(AppTheme.dark);
      expect(notifier.state.theme, AppTheme.dark);
      expect(prefs.getString('settings.theme'), 'dark');
    });
  });
}
