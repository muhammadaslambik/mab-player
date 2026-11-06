import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../core/theme/mab_theme.dart';

/// Cover lagu dengan tiga gaya: 'square', 'circle', 'vinyl' (berputar saat main).
class AlbumArt extends StatefulWidget {
  const AlbumArt({
    super.key,
    required this.style,
    required this.seed,
    required this.cover,
    required this.player,
    this.size = 260,
    this.anim = true,
  });

  final String style;
  final int seed;
  final Uint8List? cover;
  final Player player;
  final double size;
  final bool anim;

  @override
  State<AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<AlbumArt> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 18));
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.player.stream.playing.listen((_) => _sync());
    _sync();
  }

  void _sync() {
    final go = widget.anim && widget.style == 'vinyl' && widget.player.state.playing;
    if (go) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AlbumArt old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _spin.dispose();
    super.dispose();
  }

  Widget _fallback() {
    final hue = (widget.seed.abs() % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.6, 0.35).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 50) % 360, 0.6, 0.2).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: const Center(
          child: Icon(Icons.music_note_rounded, size: 56, color: Colors.white70)),
    );
  }

  Widget _image() {
    final art = widget.cover;
    if (art == null) return _fallback();
    return Image.memory(
      art,
      fit: BoxFit.cover,
      cacheWidth: 520, // batasi memori hasil decode
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tk = context.mab;
    final ring = tk.gradient ?? [cs.primary, cs.secondary, cs.primary];
    final glow = tk.glow
        ? [BoxShadow(color: cs.primary.withAlpha(90), blurRadius: 36, spreadRadius: -6)]
        : const <BoxShadow>[];

    final Widget art;
    switch (widget.style) {
      case 'circle':
        art = DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: glow,
            gradient: SweepGradient(colors: [...ring, ring.first]),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(child: _image()),
          ),
        );
      case 'vinyl':
        art = DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: glow,
            gradient: SweepGradient(colors: [...ring, ring.first]),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: RotationTransition(
              turns: _spin,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: const _VinylPainter(),
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.4,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(alignment: Alignment.center, children: [
                          ClipOval(child: SizedBox.expand(child: _image())),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Color(0xFF0B0B0E)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      default:
        art = DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: glow),
          child: ClipRRect(borderRadius: BorderRadius.circular(24), child: _image()),
        );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.size),
      child: AspectRatio(aspectRatio: 1, child: art),
    );
  }
}

class _VinylPainter extends CustomPainter {
  const _VinylPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B0B0E));
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 14; i++) {
      g.color = Colors.white.withAlpha(i.isEven ? 16 : 9);
      canvas.drawCircle(c, r * (0.42 + 0.55 * i / 14), g);
    }
    final sheen = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withAlpha(30),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withAlpha(30),
          Colors.transparent,
        ],
        stops: const [0, 0.08, 0.16, 0.5, 0.58, 0.66],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, sheen);
  }

  @override
  bool shouldRepaint(_VinylPainter old) => false;
}
