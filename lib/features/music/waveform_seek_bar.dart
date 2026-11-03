import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils/format.dart';

/// Seek bar bergaya waveform. Batang waveform bersifat dekoratif
/// (dibangkitkan dari path lagu), belum diekstrak dari audio asli.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.seed,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final int seed;
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  static const _bars = 72;
  late List<double> _heights = _gen(widget.seed);
  double? _drag;

  static List<double> _gen(int seed) {
    final r = Random(seed);
    return List.generate(_bars, (_) => 0.2 + 0.8 * r.nextDouble());
  }

  @override
  void didUpdateWidget(covariant WaveformSeekBar old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed) _heights = _gen(widget.seed);
  }

  double get _progress {
    if (_drag != null) return _drag!;
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
  }

  void _commit(double f) {
    widget.onSeek(Duration(milliseconds: (f * widget.duration.inMilliseconds).round()));
    setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      LayoutBuilder(builder: (context, box) {
        double frac(double dx) => (dx / box.maxWidth).clamp(0.0, 1.0).toDouble();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _commit(frac(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => setState(() => _drag = frac(d.localPosition.dx)),
          onHorizontalDragEnd: (_) => _commit(_drag ?? _progress),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(
              painter: _WavePainter(_heights, _progress, scheme.primary, scheme.outlineVariant),
            ),
          ),
        );
      }),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(fmt(widget.position), style: Theme.of(context).textTheme.labelSmall),
        Text(fmt(widget.duration), style: Theme.of(context).textTheme.labelSmall),
      ]),
    ]);
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.heights, this.progress, this.active, this.inactive);
  final List<double> heights;
  final double progress;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / heights.length;
    final paint = Paint()
      ..strokeWidth = w * 0.55
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < heights.length; i++) {
      final x = i * w + w / 2;
      final h = heights[i] * size.height;
      paint.color = (i / heights.length) < progress ? active : inactive;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.progress != progress || old.heights != heights;
}
