import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:z/auth_screens/login_screen.dart';
import 'package:z/providers/auth_provider.dart';
import 'package:z/services/auth/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late MockAuthService mockAuthService;
  late MockGoRouter mockGoRouter;

  setUp(() {
    mockAuthService = MockAuthService();
    mockGoRouter = MockGoRouter();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      child: MaterialApp(
        home: InheritedGoRouter(
          goRouter: mockGoRouter,
          child: const LoginScreen(),
        ),
      ),
    );
  }

  testWidgets('renders all expected login fields and buttons', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // email, password
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign Up'), findsWidgets);
  });

  testWidgets('shows validation errors for empty fields', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // The button has text 'Sign In'
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows validation error for invalid email', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.byType(TextFormField).first, 'invalidemail');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Please enter a valid email'), findsOneWidget);
  });

  testWidgets('successful email login calls sign in and navigates', (
    tester,
  ) async {
    when(
      () => mockAuthService.signInWithEmail(
        email: 'test@test.com',
        password: 'password123',
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(createWidgetUnderTest());

    await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    verify(
      () => mockAuthService.signInWithEmail(
        email: 'test@test.com',
        password: 'password123',
      ),
    ).called(1);

    await tester.pumpAndSettle();

    verify(() => mockGoRouter.go('/')).called(1);
  });
}
