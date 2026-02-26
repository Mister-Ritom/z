import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:z/screens/creation/creation_screen.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/providers/storage_provider.dart';
import 'package:z/services/content/zaps/zap_service.dart';
import 'package:z/models/zap_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class MockZapService extends Mock implements ZapService {}

// Mock UploadNotifier that implements the methods needed and has a mock Ref
class MockUploadNotifier extends Mock implements UploadNotifier {}

class MockRef extends Mock implements Ref {}

void main() {
  late MockZapService mockZapService;
  late MockUploadNotifier mockUploadNotifier;

  setUpAll(() {
    registerFallbackValue(
      ZapModel(
        id: 'mock_id',
        userId: 'mock_user_id',
        text: 'mock',
        createdAt: DateTime.now(),
        isShort: false,
      ),
    );
    registerFallbackValue(UploadType.zap);
  });

  setUp(() {
    mockZapService = MockZapService();
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
        zapServiceProvider(false).overrideWithValue(mockZapService),
        uploadNotifierProvider.overrideWith((ref) => mockUploadNotifier),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          // Watch the provider so it initializes and receives the stream value
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
            home: const CreationScreen(initialIndex: 0),
          );
        },
      ),
    );
  }

  testWidgets('renders PostCreation UI elements', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(CoolTextField), findsOneWidget);
    expect(find.text("No media selected"), findsOneWidget); // Default state
    expect(find.text("Privacy"), findsOneWidget);
    expect(find.text("Quick Actions"), findsOneWidget);
    expect(find.text("Next"), findsOneWidget); // Action button
  });

  testWidgets('empty post shows snackbar', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap Next
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    // Should show error snackbar
    expect(find.text("Cannot upload empty post"), findsOneWidget);
    verifyNever(() => mockZapService.createZap(any()));
  });

  testWidgets('text post without media calls createZap', (tester) async {
    when(() => mockZapService.createZap(any())).thenAnswer(
      (_) async => ZapModel(
        id: 'mock_id',
        userId: 'mock_user_id',
        text: 'mock',
        createdAt: DateTime.now(),
        isShort: false,
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Enter text
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'Hello World');

    // Tap Next
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    final snck = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    );
    if (snck.evaluate().isNotEmpty) {
      final textWidget = tester.widget<Text>(snck.first);
      print("Found snackbars: ${textWidget.data}");
    }

    verify(() => mockZapService.createZap(any())).called(1);
  });

  testWidgets('post with media calls upload and createZap', (tester) async {
    when(
      () => mockUploadNotifier.uploadFiles(
        files: any(named: 'files'),
        type: any(named: 'type'),
        referenceId: any(named: 'referenceId'),
      ),
    ).thenAnswer((_) async => ['https://url.com/a.jpg']);

    when(() => mockZapService.createZap(any())).thenAnswer(
      (_) async => ZapModel(
        id: 'mock_id',
        userId: 'mock_user_id',
        text: 'Hello Media',
        mediaUrls: ['https://url.com/a.jpg'],
        createdAt: DateTime.now(),
        isShort: false,
      ),
    );

    // Render with initialMedia
    await tester.pumpWidget(
      ProviderScope(
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
          zapServiceProvider(false).overrideWithValue(mockZapService),
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
              home: CreationScreen(
                initialIndex: 0,
                initialMedia: [XFile('test.jpg')],
                initialText: 'Hello Media',
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Next
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    verify(
      () => mockUploadNotifier.uploadFiles(
        files: any(named: 'files'),
        type: any(named: 'type'),
        referenceId: any(named: 'referenceId'),
      ),
    ).called(1);
    verify(() => mockZapService.createZap(any())).called(1);
  });
}
