import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' show Player;

/// Tiga batang equalizer kecil yang menari saat musik main (hanya dipakai
/// pada baris lagu aktif, jadi hanya satu controller yang berjalan).
class EqBars extends StatefulWidget {
  const EqBars({
    super.key,
    required this.player,
    required this.color,
    this.animate = true,
    this.size = 20,
  });

  final Player player;
  final Color color;
  final bool animate;
  final double size;

  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.player.stream.playing.listen((_) => _sync());
    _sync();
  }

  void _sync() {
    final go = widget.animate && widget.player.state.playing;
    if (go) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant EqBars old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _EqPainter(_c, widget.color),
        ),
      );
}

class _EqPainter extends CustomPainter {
  _EqPainter(this.anim, this.color) : super(repaint: anim);
  final Animation<double> anim;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width / 6;
    const speeds = [1.0, 1.6, 1.25];
    const phases = [0.0, 0.33, 0.66];
    for (var i = 0; i < 3; i++) {
      final s = math.sin(2 * math.pi * (anim.value * speeds[i] + phases[i]));
      final h = size.height * (0.3 + 0.7 * (0.5 + 0.5 * s));
      final x = size.width * (0.2 + 0.3 * i);
      canvas.drawLine(Offset(x, size.height - 1), Offset(x, size.height - h), paint);
    }
  }

  @override
  bool shouldRepaint(_EqPainter old) => old.color != color;
}
