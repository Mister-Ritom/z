import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ZapRepostBanner extends StatefulWidget {
  final String username;
  final VoidCallback onTap;

  const ZapRepostBanner({
    super.key,
    required this.username,
    required this.onTap,
  });

  @override
  State<ZapRepostBanner> createState() => _ZapRepostBannerState();
}

class _ZapRepostBannerState extends State<ZapRepostBanner> {
  late final TapGestureRecognizer _tapRecognizer;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()..onTap = widget.onTap;
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: 'Reposted by ',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        children: [
          TextSpan(
            text: widget.username,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
            recognizer: _tapRecognizer,
          ),
        ],
      ),
    );
  }
}
