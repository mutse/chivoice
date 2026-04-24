import 'package:flutter/material.dart';

import '../theme.dart';

class InkWashBackground extends StatelessWidget {
  const InkWashBackground({
    super.key,
    required this.child,
    this.showFooterWash = true,
  });

  final Widget child;
  final bool showFooterWash;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFCF8), kPaper, Color(0xFFF3E9DA)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -24,
            child: _WashBlob(
              width: 220,
              height: 220,
              color: secondary.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: _WashBlob(
              width: 180,
              height: 180,
              color: primary.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: showFooterWash ? -34 : -120,
            left: -10,
            right: -10,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(double.infinity, 190),
                painter: _MountainPainter(
                  primary: primary.withValues(alpha: 0.12),
                  secondary: secondary.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _WashBlob extends StatelessWidget {
  const _WashBlob({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
        child: SizedBox(width: width, height: height),
      ),
    );
  }
}

class _MountainPainter extends CustomPainter {
  const _MountainPainter({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()..color = secondary;
    final front = Paint()..color = primary;

    final backPath = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.34,
        size.width * 0.34,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.36,
        size.width * 0.64,
        size.height * 0.64,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.46,
        size.width,
        size.height * 0.7,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final frontPath = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.54,
        size.width * 0.3,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.46,
        size.width * 0.7,
        size.height * 0.78,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.62,
        size.width,
        size.height * 0.83,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(backPath, back);
    canvas.drawPath(frontPath, front);
  }

  @override
  bool shouldRepaint(covariant _MountainPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.secondary != secondary;
  }
}
