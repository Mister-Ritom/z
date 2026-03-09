import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cooler_ui/cooler_ui.dart';
import 'package:z/models/zap_model.dart';
import 'package:z/models/user_model.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/zap_provider.dart';
import 'package:z/providers/interaction_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/services/social/interaction_service.dart';
import 'package:z/services/content/zaps/zap_service.dart';
import 'package:z/services/moderation/block_service.dart';
import 'package:z/services/moderation/report_service.dart';
import 'package:z/providers/moderation_provider.dart';
import 'package:z/widgets/zap/card/zap_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:z/widgets/moderation/report_dialog.dart';
import 'package:z/info/zap/zap_detail_screen.dart';

class MockInteractionService extends Mock implements InteractionService {}

class MockZapService extends Mock implements ZapService {}

class MockBlockService extends Mock implements BlockService {}

class MockReportService extends Mock implements ReportService {}

class MockProfileService
    extends
        Mock {} // ProfileService uses Supabase directly mostly, but let's see

void main() {
  late MockInteractionService mockInteractionService;
  late MockZapService mockZapService;
  late MockBlockService mockBlockService;
  late MockReportService mockReportService;

  final testUser = UserModel(
    id: 'test_user_id',
    username: 'testuser',
    displayName: 'Test User',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testZap = ZapModel(
    id: 'test_zap_id',
    userId: 'test_user_id',
    text: 'Hello Interaction',
    createdAt: DateTime.now(),
    likesCount: 10,
    repliesCount: 5,
  );

  setUpAll(() {
    registerFallbackValue(testZap);
  });

  setUp(() {
    mockInteractionService = MockInteractionService();
    mockZapService = MockZapService();
    mockBlockService = MockBlockService();
    mockReportService = MockReportService();
  });

  Widget createWidgetUnderTest({ZapModel? zap, bool isLiked = false}) {
    final targetZap = zap ?? testZap;
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
        userProfileProvider(targetZap.userId).overrideWith((ref) => testUser),
        interactionServiceProvider(
          false,
        ).overrideWithValue(mockInteractionService),
        zapServiceProvider(false).overrideWithValue(mockZapService),
        blockServiceProvider.overrideWithValue(mockBlockService),
        reportServiceProvider.overrideWithValue(mockReportService),
        postLikedProvider((
          'test_user_id',
          targetZap.id,
          false,
        )).overrideWith((ref) => isLiked),
        isBookmarkedProvider((
          zapId: targetZap.id,
          userId: 'test_user_id',
        )).overrideWith((ref) => false),
      ],
      child: MaterialApp(
        theme: ThemeData(
          extensions: [
            CoolThemeExtension(
              primaryColor: Colors.blue,
              secondaryColor: Colors.green,
              themeMode: ThemeMode.light,
            ),
          ],
        ),
        home: Scaffold(body: ZapCard(zap: targetZap)),
      ),
    );
  }

  testWidgets('renders ZapCard with interactions', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(
      find.text('"Hello Interaction"'),
      findsOneWidget,
    ); // Text-only posts are quoted
    expect(find.text('10'), findsOneWidget); // Likes
    expect(find.text('5'), findsOneWidget); // Replies
  });

  testWidgets('tapping like calls interaction service', (tester) async {
    when(
      () => mockInteractionService.toggleLike(any(), any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.heart));
    await tester.pumpAndSettle();

    verify(
      () => mockInteractionService.toggleLike('test_user_id', 'test_zap_id'),
    ).called(1);
  });

  testWidgets('tapping boost calls interaction service', (tester) async {
    when(
      () => mockInteractionService.toggleRepost(any(), any()),
    ).thenAnswer((_) async {});

    // Need a different user for boost to work (ZapCard checks currentUserId == zap.userId)
    final otherZap = testZap.copyWith(userId: 'other_user_id');

    await tester.pumpWidget(createWidgetUnderTest(zap: otherZap));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boost'));
    await tester.pumpAndSettle();

    verify(
      () => mockInteractionService.toggleRepost('test_user_id', 'test_zap_id'),
    ).called(1);
  });

  testWidgets('tapping share calls interaction service', (tester) async {
    when(() => mockInteractionService.share(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.share2));
    await tester.pumpAndSettle();

    verify(() => mockInteractionService.share('test_zap_id')).called(1);
  });

  testWidgets('tapping bookmark calls zap service', (tester) async {
    when(
      () => mockZapService.bookmarkZap(any(), any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.bookmark));
    await tester.pumpAndSettle();

    verify(
      () => mockZapService.bookmarkZap('test_zap_id', 'test_user_id'),
    ).called(1);
  });

  testWidgets('tapping menu then report shows report dialog', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap more icon to show menu
    await tester.tap(find.byIcon(LucideIcons.ellipsis));
    await tester.pumpAndSettle();

    expect(find.text('Report Violation'), findsOneWidget);
    await tester.tap(find.text('Report Violation'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportDialog), findsOneWidget);
    expect(find.text('Why are you reporting this?'), findsOneWidget);
  });

  testWidgets('tapping menu then block shows block dialog and calls service', (
    tester,
  ) async {
    when(
      () => mockBlockService.blockUser(any(), any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap more icon to show menu
    await tester.tap(find.byIcon(LucideIcons.ellipsis));
    await tester.pumpAndSettle();

    expect(find.text('Block @testuser'), findsOneWidget);
    await tester.tap(find.text('Block @testuser'));
    await tester.pumpAndSettle();

    expect(find.text('Block @testuser?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Block'));
    await tester.pumpAndSettle();

    verify(
      () => mockBlockService.blockUser('test_user_id', 'test_user_id'),
    ).called(1);
  });

  testWidgets('tapping ZapCard navigates to ZapDetailScreen', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('"Hello Interaction"'));
    await tester.pumpAndSettle();

    expect(find.byType(ZapDetailScreen), findsOneWidget);
  });

  testWidgets('tapping comment icon navigates to ZapDetailScreen', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.messageCircle));
    await tester.pumpAndSettle();

    expect(find.byType(ZapDetailScreen), findsOneWidget);
  });
}
