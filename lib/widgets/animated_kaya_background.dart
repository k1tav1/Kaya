import 'dart:math';
import 'package:flutter/material.dart';

/// AnimatedKayaBackground
/// ----------------------
/// A reusable animated background with:
/// 1) Slowly shifting gradient
/// 2) Soft floating translucent blobs (no packages)
///
/// Usage:
///   Stack(
///     children: [
///       const AnimatedKayaBackground(),
///       YourPageContent(),
///     ],
///   )
class AnimatedKayaBackground extends StatefulWidget {
  const AnimatedKayaBackground({super.key});

  @override
  State<AnimatedKayaBackground> createState() => _AnimatedKayaBackgroundState();
}

class _AnimatedKayaBackgroundState extends State<AnimatedKayaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Alignment _lerpAlignment(Alignment a, Alignment b, double t) {
    return Alignment(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // Smoothly animate gradient alignment
        final begin = _lerpAlignment(
          Alignment.topLeft,
          Alignment.bottomRight,
          t,
        );
        final end = _lerpAlignment(Alignment.bottomRight, Alignment.topLeft, t);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: const [
                Color(0xFF1B5E20), // deep green
                Color(0xFF43A047), // green
                Color(0xFF0F4C81), // blue hint (fintech feel)
              ],
            ),
          ),
          child: Stack(
            children: const [
              _Blob(size: 240, x: -0.7, y: -0.8, speed: 0.9),
              _Blob(size: 180, x: 0.8, y: -0.6, speed: 1.2),
              _Blob(size: 220, x: 0.9, y: 0.9, speed: 0.8),
              _Blob(size: 160, x: -0.8, y: 0.8, speed: 1.1),
            ],
          ),
        );
      },
    );
  }
}

class _Blob extends StatefulWidget {
  final double size;
  final double x; // alignment x (-1 to 1)
  final double y; // alignment y (-1 to 1)
  final double speed;

  const _Blob({
    required this.size,
    required this.x,
    required this.y,
    required this.speed,
  });

  @override
  State<_Blob> createState() => _BlobState();
}

class _BlobState extends State<_Blob> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (6000 / widget.speed).round()),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;

        // Small floating motion using sine/cosine
        final dx = 0.06 * sin(2 * pi * t);
        final dy = 0.06 * cos(2 * pi * t);

        return Align(
          alignment: Alignment(widget.x + dx, widget.y + dy),
          child: IgnorePointer(
            // ensures blobs never block taps
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
        );
      },
    );
  }
}
