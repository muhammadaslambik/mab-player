import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../core/app_activity.dart';

/// Tiga batang equalizer kecil yang menari saat musik main. Hemat CPU:
/// digerakkan timer ~11 fps (bukan 60 fps) dan berhenti total saat jeda.
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

class _EqBarsState extends State<EqBars> {
  final _phase = ValueNotifier<double>(0);
  Timer? _timer;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.player.stream.playing.listen((_) => _sync());
    AppActivity.instance.active.addListener(_sync);
    _sync();
  }

  void _sync() {
    final go = widget.animate &&
        widget.player.state.playing &&
        AppActivity.instance.active.value;
    if (go) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 90), (_) {
        _phase.value = (_phase.value + 0.06) % 1.0;
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didUpdateWidget(covariant EqBars old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    AppActivity.instance.active.removeListener(_sync);
    _timer?.cancel();
    _sub?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _EqPainter(_phase, widget.color),
        ),
      );
}

class _EqPainter extends CustomPainter {
  _EqPainter(this.phase, this.color) : super(repaint: phase);
  final ValueListenable<double> phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width / 6;
    const speeds = [2.0, 3.0, 1.0];
    const offs = [0.0, 0.33, 0.66];
    for (var i = 0; i < 3; i++) {
      final s = math.sin(2 * math.pi * (phase.value * speeds[i] + offs[i]));
      final h = size.height * (0.3 + 0.7 * (0.5 + 0.5 * s));
      final x = size.width * (0.2 + 0.3 * i);
      canvas.drawLine(Offset(x, size.height - 1), Offset(x, size.height - h), paint);
    }
  }

  @override
  bool shouldRepaint(_EqPainter old) => old.color != color;
}
