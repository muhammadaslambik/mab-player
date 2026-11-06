import 'dart:async';
import 'dart:math' show Random, max, min;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../core/theme/mab_theme.dart';
import '../../core/utils/format.dart';

/// Seek bar bergaya waveform. Batang waveform bersifat dekoratif
/// (dibangkitkan dari path lagu), belum diekstrak dari audio asli.
///
/// Ringan: posisi tidak memicu rebuild widget. Hanya kanvas yang digambar
/// ulang (lewat `repaint:`) dan label waktu yang berubah sekali per detik.
/// [style]: 'bars' | 'mirror' | 'line'.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.player,
    required this.seed,
    required this.onSeek,
    this.style = 'bars',
  });

  final Player player;
  final int seed;
  final ValueChanged<Duration> onSeek;
  final String style;

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
    final cs = Theme.of(context).colorScheme;
    final grad = context.mab.gradient ?? [cs.primary, cs.primary];
    final label = Theme.of(context).textTheme.labelSmall;
    final height = switch (widget.style) {
      'line' => 28.0,
      'mirror' => 64.0,
      _ => 56.0,
    };
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
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _WavePainter(
                  _heights,
                  _progress,
                  widget.style,
                  grad,
                  cs.outlineVariant,
                ),
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
  _WavePainter(this.heights, this.progress, this.style, this.grad, this.inactive)
      : super(repaint: progress);

  final List<double> heights;
  final ValueListenable<double> progress;
  final String style;
  final List<Color> grad;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    if (style == 'line') {
      _line(canvas, size, p);
    } else {
      _bars(canvas, size, p, style == 'mirror');
    }
  }

  void _bars(Canvas canvas, Size size, double p, bool mirror) {
    final n = heights.length;
    final w = size.width / n;
    final multi = grad.length > 1;
    final paint = Paint()
      ..strokeWidth = w * 0.55
      ..strokeCap = StrokeCap.round;
    final baseY = size.height * 0.6;
    for (var i = 0; i < n; i++) {
      final x = i * w + w / 2;
      final c = gradientAt(grad, n <= 1 ? 0.0 : i / (n - 1));
      final played = (i / n) < p;
      final top = played ? c : (multi ? c.withAlpha(70) : inactive);
      paint.color = top;
      if (!mirror) {
        final h = heights[i] * size.height;
        canvas.drawLine(
            Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
      } else {
        final up = heights[i] * baseY;
        canvas.drawLine(Offset(x, baseY - up), Offset(x, baseY), paint);
        paint.color = played ? c.withAlpha(90) : inactive.withAlpha(25);
        final down = heights[i] * (size.height - baseY) * 0.7;
        canvas.drawLine(Offset(x, baseY + 3), Offset(x, baseY + 3 + down), paint);
      }
    }
  }

  void _line(Canvas canvas, Size size, double p) {
    final cy = size.height / 2;
    final track = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - 2, size.width, 4), const Radius.circular(2));
    canvas.drawRRect(track, Paint()..color = inactive);
    final w = size.width * p;
    if (w > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w, size.height));
      canvas.drawRRect(
        track,
        Paint()
          ..shader = LinearGradient(colors: grad.length > 1 ? grad : [grad.first, grad.first])
              .createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
      canvas.restore();
    }
    final x = min(max(w, 7.0), size.width - 7.0);
    canvas.drawCircle(Offset(x, cy), 7, Paint()..color = gradientAt(grad, p));
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.heights != heights ||
      old.style != style ||
      old.grad != grad ||
      old.inactive != inactive;
}
