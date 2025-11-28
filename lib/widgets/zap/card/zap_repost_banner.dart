import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ZapRepostBanner extends StatelessWidget {
  final String username;
  final VoidCallback onTap;

  const ZapRepostBanner({
    super.key,
    required this.username,
    required this.onTap,
  });

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
            text: username,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()..onTap = onTap,
          ),
        ],
      ),
    );
  }
}
