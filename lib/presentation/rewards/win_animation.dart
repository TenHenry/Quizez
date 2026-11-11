import 'dart:math';

import 'package:flutter/material.dart';

/// Animation played over the final screen of a game that the player won (bought in the shop).
/// [animationId] is the id of the shop item: `anim_confetti`, `anim_stars` or `anim_balloons`.
class WinAnimation extends StatefulWidget {
  const WinAnimation({super.key, required this.animationId});

  final String animationId;

  @override
  State<WinAnimation> createState() => _WinAnimationState();
}

class _Particle {
  _Particle(Random random)
      : x = random.nextDouble(),
        delay = random.nextDouble() * 0.5,
        speed = 0.6 + random.nextDouble() * 0.6,
        size = 14 + random.nextDouble() * 14,
        spin = random.nextDouble() * 6,
        color = Colors.primaries[random.nextInt(Colors.primaries.length)];

  final double x; // horizontal position, 0-1
  final double delay; // start offset, 0-0.5
  final double speed;
  final double size;
  final double spin;
  final Color color;
}

class _WinAnimationState extends State<WinAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..forward();
  final _particles = List.generate(36, (_) => _Particle(Random()));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(
            progress: _controller.value,
            particles: _particles,
            animationId: widget.animationId,
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress, required this.particles, required this.animationId});

  final double progress;
  final List<_Particle> particles;
  final String animationId;

  @override
  void paint(Canvas canvas, Size size) {
    final rises = animationId == 'anim_balloons';
    final glyph = switch (animationId) {
      'anim_stars' => '⭐',
      'anim_balloons' => '🎈',
      _ => null, // confetti = colored pieces
    };

    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0) * p.speed;
      if (t <= 0 || t >= 1) continue;

      final x = p.x * size.width + sin(t * 8 + p.spin) * 18;
      final y = rises ? size.height * (1 - t) : size.height * t;

      if (glyph != null) {
        final painter = TextPainter(
          text: TextSpan(text: glyph, style: TextStyle(fontSize: p.size)),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x, y));
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(t * 10 + p.spin);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size * 0.6, height: p.size * 0.3), Paint()..color = p.color);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
