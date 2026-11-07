import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../core/app_activity.dart';

/// Tiga batang equalizer kecil yang menari saat musik main. Hemat CPU:
/// digerakkan timer (6 fps hemat / 11 fps penuh), berhenti total saat jeda,
/// saat jendela tidak aktif, atau saat animasi dimatikan.
class EqBars extends StatefulWidget {
  const EqBars({
    super.key,
    required this.player,
    required this.color,
    this.motion = 'low',
    this.size = 20,
  });

  final Player player;
  final Color color;
  final String motion; // off | low | full
  final double size;

  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> {
  final _phase = ValueNotifier<double>(0);
  Timer? _timer;
  int _ms = 0;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.player.stream.playing.listen((_) => _sync());
    AppActivity.instance.active.addListener(_sync);
    _sync();
  }

  void _sync() {
    final ms = widget.motion == 'full' ? 90 : 170;
    final go = widget.motion != 'off' &&
        widget.player.state.playing &&
        AppActivity.instance.active.value;
    if (!go) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null && _ms == ms) return;
    _timer?.cancel();
    _ms = ms;
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) {
      _phase.value = (_phase.value + ms / 1500) % 1.0;
    });
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
