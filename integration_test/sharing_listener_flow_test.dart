import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:listen_sharing_intent/listen_sharing_intent.dart';
import 'package:z/providers/sharing_provider.dart';
import 'package:z/services/sharing_service.dart';
import 'package:z/utils/router.dart';
import 'package:z/widgets/sharing/sharing_listener.dart';

class _FakeSharingService extends SharingService {
  _FakeSharingService(this._controller);

  final StreamController<List<SharedMediaFile>> _controller;

  void emit(List<SharedMediaFile> files) {
    _controller.add(files);
  }

  @override
  void initialize() {}

  @override
  Stream<List<SharedMediaFile>> get sharedMediaStream => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigates to share route when shared media arrives', (
    WidgetTester tester,
  ) async {
    final controller = StreamController<List<SharedMediaFile>>.broadcast();
    final sharingService = _FakeSharingService(controller);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/share',
          builder: (context, state) {
            final files = state.extra as List<SharedMediaFile>? ?? [];
            return Scaffold(body: Text('Share Count: ${files.length}'));
          },
        ),
      ],
    );

    addTearDown(router.dispose);
    addTearDown(sharingService.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharingServiceProvider.overrideWithValue(sharingService),
          routerProvider.overrideWithValue(router),
        ],
        child: SharingListener(child: MaterialApp.router(routerConfig: router)),
      ),
    );

    await tester.pumpAndSettle();

    sharingService.emit([
      SharedMediaFile(path: '/tmp/test.jpg', type: SharedMediaType.image),
    ]);

    await tester.pumpAndSettle();

    expect(find.text('Share Count: 1'), findsOneWidget);
  });
}
