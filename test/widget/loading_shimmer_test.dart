import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z/widgets/common/loading_shimmer.dart';

void main() {
  testWidgets('ZapCardShimmer renders placeholder skeletons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ZapCardShimmer())),
    );

    final shimmerWidgets = tester.widgetList(find.byType(LoadingShimmer));
    expect(shimmerWidgets.length, 8);
    expect(find.byType(ZapCardShimmer), findsOneWidget);
  });

  testWidgets('LoadingShimmer uses provided dimensions', (
    WidgetTester tester,
  ) async {
    const size = Size(120, 24);
    const testKey = ValueKey('loading-shimmer');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingShimmer(
            key: testKey,
            width: size.width,
            height: size.height,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    final shimmer = tester.widget<LoadingShimmer>(find.byKey(testKey));
    expect(shimmer.width, size.width);
    expect(shimmer.height, size.height);
    expect(shimmer.borderRadius, isNotNull);
  });
}
