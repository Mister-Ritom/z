import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:z/auth_screens/signup_screen.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/providers/profile_provider.dart';
import 'package:z/services/auth/auth_service.dart';
import 'package:z/services/social/profile_service.dart';
import 'package:z/services/analytics/analytics_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockProfileService extends Mock implements ProfileService {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late MockAuthService mockAuthService;
  late MockProfileService mockProfileService;
  late MockAnalyticsService mockAnalyticsService;
  late MockGoRouter mockGoRouter;

  setUp(() {
    mockAuthService = MockAuthService();
    mockProfileService = MockProfileService();
    mockAnalyticsService = MockAnalyticsService();
    mockGoRouter = MockGoRouter();

    when(
      () => mockAnalyticsService.capture(
        eventName: any(named: 'eventName'),
        properties: any(named: 'properties'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        profileServiceProvider.overrideWithValue(mockProfileService),
        analyticsServiceProvider.overrideWithValue(mockAnalyticsService),
      ],
      child: MaterialApp(
        home: InheritedGoRouter(
          goRouter: mockGoRouter,
          child: const SignUpScreen(),
        ),
      ),
    );
  }

  testWidgets('renders all expected signup fields and buttons', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('Create your account'), findsOneWidget);
    expect(
      find.byType(TextFormField),
      findsNWidgets(4),
    ); // display name, username, email, password
    expect(find.text('Sign Up'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('shows validation errors for empty fields', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pump();

    expect(find.text('Display name is required'), findsOneWidget);
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows validation error for taken username', (tester) async {
    when(
      () => mockProfileService.isUsernameAvailable('takenuser'),
    ).thenAnswer((_) async => false);

    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'takenuser');
    await tester.enterText(find.byType(TextFormField).at(2), 'test@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => mockProfileService.isUsernameAvailable('takenuser')).called(1);
    expect(find.text('Username already taken'), findsOneWidget);
  });

  testWidgets('successful sign up calls sign up and navigates', (tester) async {
    when(
      () => mockProfileService.isUsernameAvailable('newuser'),
    ).thenAnswer((_) async => true);
    when(
      () => mockAuthService.signUpWithEmail(
        email: 'test@test.com',
        password: 'password123',
        username: 'newuser',
        displayName: 'Test User',
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.byType(TextFormField).at(0), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(1), 'newuser');
    await tester.enterText(find.byType(TextFormField).at(2), 'test@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pump(); // Loading state

    verify(() => mockProfileService.isUsernameAvailable('newuser')).called(1);
    verify(
      () => mockAuthService.signUpWithEmail(
        email: 'test@test.com',
        password: 'password123',
        username: 'newuser',
        displayName: 'Test User',
      ),
    ).called(1);

    await tester.pumpAndSettle();

    verify(() => mockGoRouter.pushReplacement('/')).called(1);
  });
}
