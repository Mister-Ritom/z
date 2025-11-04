import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'package:flutter/foundation.dart';

/// A universal glass container that uses oc_liquid_glass for realistic GPU-accelerated effects.
/// Falls back to a blurred container on web or unsupported platforms.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final double borderRadius;
  final Color color;

  const GlassContainer({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = 20,
    this.color = const Color.fromARGB(50, 255, 255, 255),
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Fallback for web (blur effect only)
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          backgroundBlendMode: BlendMode.overlay,
        ),
        child: child,
      );
    }

    // Native (Impeller supported platforms)
    return OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(
        refractStrength: -0.08,
        blurRadiusPx: 2.5,
        specStrength: 20.0,
        lightbandColor: Colors.white54,
      ),
      child: OCLiquidGlass(
        width: width,
        height: height,
        borderRadius: borderRadius,
        color: color,
        child: child,
      ),
    );
  }
}

/// Example: A glassy card widget.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: borderRadius,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A glass button using oc_liquid_glass underneath.
class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const GlassButton({super.key, required this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassContainer(
        height: 50,
        borderRadius: 14,
        color: Colors.white.withAlpha(50),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// A Floating Action Button that uses oc_liquid_glass for realistic shader-based glass effects.
/// Falls back to a visually consistent Material FAB on web.
class GlassFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double size;
  final Color color;
  final double borderRadius;
  final double blurRadius;
  final double refractStrength;
  final double specStrength;
  final Color lightbandColor;
  final BoxShadow? shadow;

  const GlassFAB({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = 64,
    this.color = const Color.fromARGB(80, 255, 255, 255),
    this.borderRadius = 32,
    this.blurRadius = 2.5,
    this.refractStrength = -0.08,
    this.specStrength = 20.0,
    this.lightbandColor = Colors.white54,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web fallback with matching look and size
      return SizedBox(
        width: size,
        height: size,
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: color.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      );
    }

    // oc_liquid_glass version for native
    return GestureDetector(
      onTap: onPressed,
      child: OCLiquidGlassGroup(
        settings: OCLiquidGlassSettings(
          refractStrength: refractStrength,
          blurRadiusPx: blurRadius,
          specStrength: specStrength,
          lightbandColor: lightbandColor,
        ),
        child: OCLiquidGlass(
          width: size,
          height: size,
          borderRadius: borderRadius,
          color: color,
          shadow:
              shadow ??
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
          child: child,
        ),
      ),
    );
  }
}
