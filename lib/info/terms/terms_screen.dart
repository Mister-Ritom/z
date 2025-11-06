import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:z/screens/main_navigation.dart';
import 'package:z/utils/constants.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
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
          ..loadRequest(Uri.parse('${AppConstants.appUrl}/terms'));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final progressColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
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
