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

class MockUploadNotifier extends Mock implements UploadNotifier {}

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
        isShort: true,
      ),
    );
    registerFallbackValue(UploadType.shorts);
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
        zapServiceProvider(true).overrideWithValue(mockZapService),
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
            home: const CreationScreen(initialIndex: 2), // Shorts page
          );
        },
      ),
    );
  }

  testWidgets('renders ShortsCreation UI elements', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text("No media selected"), findsOneWidget);
    expect(find.byType(CoolTextField), findsOneWidget);
  });

  testWidgets('shorts creation calls upload and createZap', (tester) async {
    when(
      () => mockUploadNotifier.uploadFiles(
        files: any(named: 'files'),
        type: any(named: 'type'),
        referenceId: any(named: 'referenceId'),
      ),
    ).thenAnswer((_) async => ['https://url.com/a.mp4']);

    when(() => mockZapService.createZap(any())).thenAnswer(
      (_) async => ZapModel(
        id: 'mock_id',
        userId: 'test_user_id',
        text: 'Hello Shorts',
        mediaUrls: ['https://url.com/a.mp4'],
        createdAt: DateTime.now(),
        isShort: true,
      ),
    );

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
          zapServiceProvider(true).overrideWithValue(mockZapService),
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
                initialIndex: 2,
                initialMedia: [XFile('test.mp4')],
                initialText: 'Hello Shorts',
              ),
            );
          },
        ),
      ),
    );

    await tester
        .pump(); // Use pump instead of pumpAndSettle to avoid timeout from VideoPlayer loading
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text("Next"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(
      () => mockUploadNotifier.uploadFiles(
        files: any(named: 'files'),
        type: UploadType.shorts,
        referenceId: any(named: 'referenceId'),
      ),
    ).called(1);
    verify(() => mockZapService.createZap(any())).called(1);
  });
}
