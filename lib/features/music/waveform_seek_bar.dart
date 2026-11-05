import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../core/utils/format.dart';

/// Seek bar bergaya waveform. Batang waveform bersifat dekoratif
/// (dibangkitkan dari path lagu), belum diekstrak dari audio asli.
///
/// Ringan: posisi tidak memicu rebuild widget. Hanya kanvas yang digambar
/// ulang (lewat `repaint:`) dan label waktu yang berubah sekali per detik.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.player,
    required this.seed,
    required this.onSeek,
  });

  final Player player;
  final int seed;
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  static const _bars = 72;
  late List<double> _heights = _gen(widget.seed);

  final _progress = ValueNotifier<double>(0);
  final _posSec = ValueNotifier<int>(0);
  final _durSec = ValueNotifier<int>(0);
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _dragging = false;
  final _subs = <StreamSubscription<Duration>>[];

  static List<double> _gen(int seed) {
    final r = Random(seed);
    return List.generate(_bars, (_) => 0.2 + 0.8 * r.nextDouble());
  }

  @override
  void initState() {
    super.initState();
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _sync();
    _subs.add(widget.player.stream.position.listen((d) {
      _position = d;
      _sync();
    }));
    _subs.add(widget.player.stream.duration.listen((d) {
      _duration = d;
      _sync();
    }));
  }

  void _sync() {
    final total = _duration.inMilliseconds;
    final f = total <= 0
        ? 0.0
        : (_position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
    if (!_dragging) _progress.value = f;
    _posSec.value = _position.inSeconds;
    _durSec.value = _duration.inSeconds;
  }

  @override
  void didUpdateWidget(covariant WaveformSeekBar old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed) setState(() => _heights = _gen(widget.seed));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _progress.dispose();
    _posSec.dispose();
    _durSec.dispose();
    super.dispose();
  }

  void _commit(double f) {
    _dragging = false;
    _progress.value = f;
    widget.onSeek(Duration(milliseconds: (f * _duration.inMilliseconds).round()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.labelSmall;
    return Column(children: [
      LayoutBuilder(builder: (context, box) {
        double frac(double dx) => (dx / box.maxWidth).clamp(0.0, 1.0).toDouble();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _commit(frac(d.localPosition.dx)),
          onHorizontalDragStart: (_) => _dragging = true,
          onHorizontalDragUpdate: (d) => _progress.value = frac(d.localPosition.dx),
          onHorizontalDragEnd: (_) => _commit(_progress.value),
          onHorizontalDragCancel: () => _dragging = false,
          child: RepaintBoundary(
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: CustomPaint(
                painter: _WavePainter(
                    _heights, _progress, scheme.primary, scheme.outlineVariant),
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        ValueListenableBuilder<int>(
          valueListenable: _posSec,
          builder: (_, s, _) => Text(fmt(Duration(seconds: s)), style: label),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _durSec,
          builder: (_, s, _) => Text(fmt(Duration(seconds: s)), style: label),
        ),
      ]),
    ]);
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.heights, this.progress, this.active, this.inactive)
      : super(repaint: progress);
  final List<double> heights;
  final ValueListenable<double> progress;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / heights.length;
    final p = progress.value;
    final paint = Paint()
      ..strokeWidth = w * 0.55
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < heights.length; i++) {
      final x = i * w + w / 2;
      final h = heights[i] * size.height;
      paint.color = (i / heights.length) < p ? active : inactive;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.heights != heights || old.active != active || old.inactive != inactive;
}
