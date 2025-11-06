import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/utils/constants.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (p) => setState(() => _progress = p / 100),
            ),
          )
          ..loadRequest(Uri.parse('${AppConstants.appUrl}/privacy'));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final progressColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Container(
        color: bg,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_progress < 1)
              LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                color: progressColor,
                backgroundColor: progressColor.withOpacityAlpha(0.2),
              ),
          ],
        ),
      ),
    );
  }
}
