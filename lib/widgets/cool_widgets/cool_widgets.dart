import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Controls the direction of rotation applied to cards as they go deeper
enum RotationDirection { clockwise, anticlockwise }

/// ---------------------------------------------------------------------------
/// CoolShuffledStack
/// ---------------------------------------------------------------------------
///
/// A shuffled-card style stack widget with reliable interaction.
///
/// ─────────────────────────────────────────────────────────────────────────
/// CORE IDEA
/// ─────────────────────────────────────────────────────────────────────────
///
/// Flutter performs hit testing BEFORE transforms (scale / rotate / translate).
/// This means GestureDetector does NOT work correctly on transformed widgets.
///
/// This widget solves that by:
/// - Rendering visuals with Transform
/// - Handling gestures at the stack level
/// - Manually computing the visual bounds of each card
/// - Performing custom hit testing using geometry
///
/// Result:
/// ✔ Correct taps on rotated / scaled cards
/// ✔ No GestureDetector + Transform conflict
///
class CoolShuffledStack extends StatefulWidget {
  /// Widgets to display as cards
  final List<Widget> items;

  /// Maximum number of cards visible at once
  final int maxItemsSeen;

  /// Maximum size of the stack
  /// Required so hit-test geometry can be calculated
  final Size maxSize;

  /// Scale reduction per depth level
  final double scaleStep;

  /// Rotation (in radians) per depth level
  final double rotationStep;

  /// Direction of rotation
  final RotationDirection direction;

  /// Offset applied per depth level
  final Offset offsetStep;

  /// Curve applied to transform animations
  final Curve transformCurve;

  /// Duration of shuffle animation
  final Duration animationDuration;

  /// Reserved for future drag gestures
  final ValueChanged<int>? onDragLeft;
  final ValueChanged<int>? onDragRight;

  /// Widget shown when items overflow maxItemsSeen
  final Widget? overflowIndicator;

  const CoolShuffledStack({
    super.key,
    required this.items,
    this.maxItemsSeen = 3,
    required this.maxSize,
    this.scaleStep = 0.06,
    this.rotationStep = 0.06,
    this.direction = RotationDirection.clockwise,
    this.offsetStep = const Offset(12, 10),
    this.transformCurve = Curves.easeOutCubic,
    this.animationDuration = const Duration(milliseconds: 380),
    this.onDragLeft,
    this.onDragRight,
    this.overflowIndicator,
  });

  @override
  State<CoolShuffledStack> createState() => _CoolShuffledStackState();
}

class _CoolShuffledStackState extends State<CoolShuffledStack>
    with SingleTickerProviderStateMixin {
  /// Current order of item indices
  /// Index 0 is always the top-most card
  late List<int> _order;

  /// Keys used to measure actual rendered widget sizes
  late List<GlobalKey> _keys;

  /// Cached sizes for each widget
  final Map<int, Size> _sizes = {};

  /// Drives transform animation when cards reorder
  late AnimationController _controller;

  // ---------------------------------------------------------------------------
  // ADDED: drag tracking state
  // ---------------------------------------------------------------------------
  Offset _dragStart = Offset.zero;
  Offset _dragDelta = Offset.zero;
  bool _isDragging = false;

  static const double _dragCommitDistance = 80;
  static const double _dragVelocityThreshold = 600;
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    /// Initial order: [0, 1, 2, ...]
    _order = List<int>.generate(widget.items.length, (i) => i);

    /// One GlobalKey per item so we can measure size
    _keys = List.generate(widget.items.length, (_) => GlobalKey());

    /// Animation controller starts fully completed
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..value = 1.0;

    /// Measure sizes after first layout pass
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// -------------------------------------------------------------------------
  /// SIZE MEASUREMENT
  /// -------------------------------------------------------------------------
  ///
  /// We must know the real size of each widget to correctly compute
  /// visual bounds for hit testing.
  ///
  void _measure() {
    bool changed = false;

    for (int i = 0; i < _keys.length; i++) {
      final ctx = _keys[i].currentContext;
      if (ctx == null) continue;

      final box = ctx.findRenderObject() as RenderBox;
      final size = box.size;

      if (_sizes[i] != size) {
        _sizes[i] = size;
        changed = true;
      }
    }

    if (changed) setState(() {});
  }

  /// Returns only the items that should be rendered
  List<int> get _visibleOrder => _order.take(widget.maxItemsSeen).toList();

  /// Number of items hidden behind the stack
  int get _overflowCount =>
      math.max(0, widget.items.length - widget.maxItemsSeen);

  /// -------------------------------------------------------------------------
  /// GEOMETRY COMPUTATION
  /// -------------------------------------------------------------------------
  ///
  /// For each visible card we compute:
  /// - scale
  /// - rotation
  /// - offset
  /// - final visual bounding rectangle (AABB)
  ///
  /// These rectangles are used for manual hit testing.
  ///
  List<_ItemGeometry> _computeGeometries() {
    final center = Offset(widget.maxSize.width / 2, widget.maxSize.height / 2);

    final List<_ItemGeometry> result = [];

    for (
      int visualIndex = 0;
      visualIndex < _visibleOrder.length;
      visualIndex++
    ) {
      final index = _visibleOrder[visualIndex];
      final depth = visualIndex;

      /// Actual widget size (or fallback)
      final size = _sizes[index] ?? const Size(200, 200);

      /// Progressive transform values
      final scale = 1.0 - widget.scaleStep * depth;
      final rotation =
          widget.rotationStep *
          depth *
          (widget.direction == RotationDirection.clockwise ? 1 : -1);
      final offset = widget.offsetStep * depth.toDouble();

      /// Base rectangle BEFORE rotation
      final baseRect = Rect.fromCenter(
        center: center + offset,
        width: size.width * scale,
        height: size.height * scale,
      );

      /// Axis-aligned bounding box AFTER rotation
      final rect = _aabbForRotation(baseRect, rotation);

      result.add(
        _ItemGeometry(
          orderIndex: index,
          depth: depth,
          scale: scale,
          rotation: rotation,
          offset: offset,
          visualRect: rect,
        ),
      );
    }

    return result;
  }

  /// Computes an axis-aligned bounding box for a rotated rectangle
  Rect _aabbForRotation(Rect rect, double angle) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    Offset rot(Offset p) {
      final dx = p.dx - cx;
      final dy = p.dy - cy;
      return Offset(cx + dx * cosA - dy * sinA, cy + dx * sinA + dy * cosA);
    }

    final points = [
      rot(rect.topLeft),
      rot(rect.topRight),
      rot(rect.bottomLeft),
      rot(rect.bottomRight),
    ];

    return Rect.fromLTRB(
      points.map((e) => e.dx).reduce(math.min),
      points.map((e) => e.dy).reduce(math.min),
      points.map((e) => e.dx).reduce(math.max),
      points.map((e) => e.dy).reduce(math.max),
    );
  }

  bool _pointInItemGeometry(Offset point, _ItemGeometry g, Size size) {
    final center = Offset(widget.maxSize.width / 2, widget.maxSize.height / 2);

    Offset p = point - center;

    p -= g.offset;

    final cosA = math.cos(-g.rotation);
    final sinA = math.sin(-g.rotation);

    p = Offset(p.dx * cosA - p.dy * sinA, p.dx * sinA + p.dy * cosA);

    final halfW = size.width * g.scale / 2;
    final halfH = size.height * g.scale / 2;

    return p.dx.abs() <= halfW && p.dy.abs() <= halfH;
  }

  /// -------------------------------------------------------------------------
  /// MANUAL HIT TESTING
  /// -------------------------------------------------------------------------
  ///
  /// Detects which visual card was tapped using geometry instead of Flutter's
  /// hit testing system.
  ///
  void _handleTapDown(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);

    final geometries = _computeGeometries();

    /// Iterate from top-most to back-most
    for (int i = 0; i < geometries.length; i++) {
      final g = geometries[i];
      if (!g.visualRect.contains(local)) continue;

      final size = _sizes[g.orderIndex] ?? const Size(200, 200);

      if (!_pointInItemGeometry(local, g, size)) continue;

      /// Check if another card visually covers this point
      bool covered = false;
      for (int j = 0; j < i; j++) {
        if (geometries[j].visualRect.contains(local)) {
          covered = true;
          break;
        }
      }

      /// If not covered, this is the tapped card
      if (!covered) {
        setState(() {
          _order.remove(g.orderIndex);
          _order.insert(0, g.orderIndex);
          _controller.forward(from: 0);
        });
        break;
      }
    }
  }

  @override
  void didUpdateWidget(covariant CoolShuffledStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items.length != widget.items.length) {
      _order = List<int>.generate(widget.items.length, (i) => i);
      _keys = List.generate(widget.items.length, (_) => GlobalKey());
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  Widget build(BuildContext context) {
    final geometries = _computeGeometries();

    return SizedBox(
      width: widget.maxSize.width,
      height: widget.maxSize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: _handleTapDown,

        // -------------------------------------------------------------------
        // ADDED: drag gesture handling
        // -------------------------------------------------------------------
        onPanStart: (details) {
          _dragStart = details.globalPosition;
          _dragDelta = Offset.zero;
          _isDragging = false;
        },
        onPanUpdate: (details) {
          _dragDelta = details.globalPosition - _dragStart;
          if (!_isDragging && _dragDelta.distance > kTouchSlop) {
            _isDragging = true;
          }
        },
        onPanEnd: (details) {
          if (!_isDragging) {
            _dragDelta = Offset.zero;
            return;
          }

          _isDragging = false;

          final dx = _dragDelta.dx;
          final vx = details.velocity.pixelsPerSecond.dx;
          final frontIndex = _order.isNotEmpty ? _order.first : null;

          if (frontIndex == null) return;

          if (dx < -_dragCommitDistance || vx < -_dragVelocityThreshold) {
            widget.onDragLeft?.call(frontIndex);
          } else if (dx > _dragCommitDistance || vx > _dragVelocityThreshold) {
            widget.onDragRight?.call(frontIndex);
          }

          _dragDelta = Offset.zero;
        },

        // -------------------------------------------------------------------
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                /// Render from back to front
                for (final g in geometries.reversed) _buildItem(g),

                /// Overflow indicator
                if (_overflowCount > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child:
                        widget.overflowIndicator ??
                        CoolOverflowBadge(count: _overflowCount),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds a single card with animated transform
  Widget _buildItem(_ItemGeometry g) {
    final t = widget.transformCurve.transform(_controller.value);

    final matrix =
        Matrix4.identity()
          ..translate(
            lerpDouble(0, g.offset.dx, t)!,
            lerpDouble(0, g.offset.dy, t)!,
          )
          ..rotateZ(lerpDouble(0, g.rotation, t)!)
          ..scale(lerpDouble(1, g.scale, t)!);

    return IgnorePointer(
      /// Only the top card can receive pointer events
      ignoring: g.depth != 0,
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Center(
          child: KeyedSubtree(
            key: _keys[g.orderIndex],
            child: widget.items[g.orderIndex],
          ),
        ),
      ),
    );
  }
}

class _ItemGeometry {
  final int orderIndex;
  final int depth;
  final double scale;
  final double rotation;
  final Offset offset;
  final Rect visualRect;

  _ItemGeometry({
    required this.orderIndex,
    required this.depth,
    required this.scale,
    required this.rotation,
    required this.offset,
    required this.visualRect,
  });
}

class CoolOverflowBadge extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final TextStyle? textStyle;

  const CoolOverflowBadge({
    super.key,
    required this.count,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.radius = 14,
    this.backgroundColor = const Color(0xCC000000),
    this.textColor = const Color(0xFFFFFFFF),
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        '+$count',
        style:
            textStyle ??
            TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class CoolOverflowDot extends StatelessWidget {
  final int count;
  final double size;
  final Color color;

  const CoolOverflowDot({
    super.key,
    required this.count,
    this.size = 36,
    this.color = const Color(0xCC000000),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '+$count',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class CoolOverflowMinimal extends StatelessWidget {
  final int count;
  final Color color;

  const CoolOverflowMinimal({
    super.key,
    required this.count,
    this.color = const Color(0xFF000000),
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '+$count',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
    );
  }
}
