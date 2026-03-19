import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:z/screens/creation/creation_screen.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/stories_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/services/content/stories/story_service.dart';
import 'package:z/models/story_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class MockStoryService extends Mock implements StoryService {}

class MockUploadNotifier extends Mock implements UploadNotifier {}

void main() {
  late MockStoryService mockStoryService;
  late MockUploadNotifier mockUploadNotifier;

  setUpAll(() {
    registerFallbackValue(StoryVisibility.public);
    registerFallbackValue(UploadType.story);
  });

  setUp(() {
    mockStoryService = MockStoryService();
    mockUploadNotifier = MockUploadNotifier();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => Stream.value(
            const sb.User(
              id: 'test_user_id',
              appMetadata: {},
              userMetadata: {},
              aud: '',
              createdAt: '',
            ),
          ),
        ),
        storyServiceProvider.overrideWithValue(mockStoryService),
        uploadNotifierProvider.overrideWith((ref) => mockUploadNotifier),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          ref.watch(currentUserProvider);
          return MaterialApp(
            theme: ThemeData(
              extensions: [
                CoolThemeExtension(
                  primaryColor: Colors.blue,
                  secondaryColor: Colors.green,
                  themeMode: ThemeMode.light,
                ),
              ],
            ),
            home: const CreationScreen(initialIndex: 1), // Story page
          );
        },
      ),
    );
  }

  testWidgets('renders StoryCreation UI elements', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text("No media selected"), findsOneWidget);
    expect(find.byType(CoolTextField), findsOneWidget);
  });

  testWidgets('empty story shows snackbar', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    expect(find.text("Cannot upload empty story"), findsOneWidget);
    verifyNever(
      () => mockStoryService.createStory(
        uid: any(named: 'uid'),
        caption: any(named: 'caption'),
        mediaUrl: any(named: 'mediaUrl'),
        visibility: any(named: 'visibility'),
        visibleTo: any(named: 'visibleTo'),
      ),
    );
  });

  testWidgets('text-only story calls createStory', (tester) async {
    when(
      () => mockStoryService.createStory(
        uid: any(named: 'uid'),
        caption: any(named: 'caption'),
        mediaUrl: any(named: 'mediaUrl'),
        visibility: any(named: 'visibility'),
        visibleTo: any(named: 'visibleTo'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Toggle text mode
    await tester.tap(find.byIcon(LucideIcons.caseSensitive));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello Story');
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    verify(
      () => mockStoryService.createStory(
        uid: 'test_user_id',
        caption: 'Hello Story',
        mediaUrl: any(named: 'mediaUrl'),
        visibility: any(named: 'visibility'),
        visibleTo: any(named: 'visibleTo'),
      ),
    ).called(1);
  });
}
