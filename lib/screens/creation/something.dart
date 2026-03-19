import 'package:flutter/material.dart';

//TODO
class StoryCanvasOverlay extends StatefulWidget {
  const StoryCanvasOverlay({super.key});

  @override
  StoryCanvasOverlayState createState() => StoryCanvasOverlayState();
}

class StoryCanvasOverlayState extends State<StoryCanvasOverlay> {
  final List<_DrawPath> _paths = [];
  final List<_StickerItem> _stickers = [];

  bool drawingEnabled = false;

  void enableDrawing(bool value) {
    setState(() {
      drawingEnabled = value;
    });
  }

  void addSticker(Widget child, {Offset position = const Offset(120, 200)}) {
    setState(() {
      _stickers.add(_StickerItem(child: child, position: position));
    });
  }

  void clearDrawings() {
    setState(() {
      _paths.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart:
              drawingEnabled
                  ? (d) {
                    setState(() {
                      _paths.add(_DrawPath([d.localPosition]));
                    });
                  }
                  : null,
          onPanUpdate:
              drawingEnabled
                  ? (d) {
                    setState(() {
                      _paths.last.points.add(d.localPosition);
                    });
                  }
                  : null,
          child: CustomPaint(
            size: Size.infinite,
            painter: _DrawPainter(_paths),
          ),
        ),
        ..._stickers.map(
          (s) => Positioned(
            left: s.position.dx,
            top: s.position.dy,
            child: GestureDetector(
              onScaleUpdate: (d) {
                setState(() {
                  s.scale *= d.scale;
                  s.rotation += d.rotation;
                  s.position += d.focalPointDelta;
                });
              },
              child: Transform.rotate(
                angle: s.rotation,
                child: Transform.scale(scale: s.scale, child: s.child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawPath {
  final List<Offset> points;
  _DrawPath(this.points);
}

class _DrawPainter extends CustomPainter {
  final List<_DrawPath> paths;
  _DrawPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    for (final path in paths) {
      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StickerItem {
  Offset position;
  double scale = 1.0;
  double rotation = 0.0;
  final Widget child;

  _StickerItem({required this.child, required this.position});
}
