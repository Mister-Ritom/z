import 'dart:ui';

import 'package:flutter/material.dart';

class AnchoredOverlayController {
  OverlayEntry? _entry;

  void show({
    required BuildContext context,
    required Rect anchorRect,
    required Widget child,
  }) {
    if (_entry != null) return;

    final overlay = Overlay.of(context);

    _entry = OverlayEntry(
      builder: (_) {
        return _AnchoredOverlay(
          anchorRect: anchorRect,
          onDismiss: hide,
          child: child,
        );
      },
    );

    overlay.insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _AnchoredOverlay extends StatelessWidget {
  final Rect anchorRect;
  final Widget child;
  final VoidCallback onDismiss;

  const _AnchoredOverlay({
    required this.anchorRect,
    required this.child,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onDismiss,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),
        ),
        Positioned.fromRect(
          rect: anchorRect.inflate(4),
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        _OverlayCard(anchorRect: anchorRect, child: child),
      ],
    );
  }
}

class _OverlayCard extends StatefulWidget {
  final Rect anchorRect;
  final Widget child;

  const _OverlayCard({required this.anchorRect, required this.child});

  @override
  State<_OverlayCard> createState() => _OverlayCardState();
}

class _OverlayCardState extends State<_OverlayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    final top = widget.anchorRect.bottom + 10;
    final left = (widget.anchorRect.center.dx - 140).clamp(
      16.0,
      screen.width - 296,
    );

    return Positioned(
      top: top,
      left: left,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
