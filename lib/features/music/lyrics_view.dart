import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio_handler.dart';
import '../../services/lyrics.dart';

/// Lirik tersinkron 3/5 baris di bawah judul (hanya bila ada file .lrc).
/// Ketuk sebuah baris untuk loncat ke waktunya.
class LyricsView extends StatelessWidget {
  const LyricsView({super.key, required this.handler, this.radius = 1});
  final MabAudioHandler handler;
  final int radius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Lyrics>(
      valueListenable: handler.lyrics,
      builder: (context, l, _) {
        if (l.isEmpty || !l.synced) return const SizedBox.shrink();
        return _Synced(handler: handler, lines: l.lines, radius: radius);
      },
    );
  }
}

class _Synced extends StatelessWidget {
  const _Synced({required this.handler, required this.lines, required this.radius});
  final MabAudioHandler handler;
  final List<LyricLine> lines;
  final int radius;

  @override
  Widget build(BuildContext context) {
    final player = handler.player;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: (2 * radius + 1) * 38.0,
        child: StreamBuilder<int>(
          stream: player.stream.position.map((p) => lyricIndexAt(lines, p)).distinct(),
          initialData: lyricIndexAt(lines, player.state.position),
          builder: (context, snap) {
            final i = snap.data ?? -1;
            final from = math.max(0, i - radius);
            final to = math.min(lines.length - 1, math.max(i, 0) + radius);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(i),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = from; k <= to; k++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => handler.seek(lines[k].at),
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: k == i
                            ? BoxDecoration(
                                color: cs.primary.withAlpha(38),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: Text(
                          lines[k].text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: k == i
                              ? text.titleSmall?.copyWith(
                                  color: cs.primary, fontWeight: FontWeight.w700)
                              : text.bodyMedium
                                  ?.copyWith(color: cs.onSurface.withAlpha(150)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
