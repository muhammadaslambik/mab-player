import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../core/theme/mab_theme.dart';
import '../../providers.dart';
import 'full_player_page.dart';

/// Kartu pemutar mini (ketuk untuk membuka pemutar penuh).
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(audioHandlerProvider);
    return StreamBuilder<MediaItem?>(
      stream: h.trackInfo,
      initialData: h.mediaItem.value,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) return const SizedBox.shrink();
        final tk = context.mab;
        final cs = Theme.of(context).colorScheme;
        final artist = item.artist;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Material(
                color: tk.panel,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: tk.border),
                ),
                child: InkWell(
                  onTap: () => openFullPlayer(context),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _MiniProgress(player: h.player),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                      child: Row(children: [
                        ValueListenableBuilder<Uint8List?>(
                          valueListenable: h.cover,
                          builder: (_, cover, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: cover == null
                                  ? ColoredBox(
                                      color: cs.primary.withAlpha(36),
                                      child: Icon(Icons.music_note_rounded,
                                          color: cs.primary))
                                  : Image.memory(
                                      cover,
                                      fit: BoxFit.cover,
                                      cacheWidth: 88,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.music_note_rounded),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              if (artist != null)
                                Text(artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sebelumnya',
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: h.skipToPrevious,
                        ),
                        StreamBuilder<bool>(
                          stream: h.player.stream.playing,
                          initialData: h.player.state.playing,
                          builder: (_, p) {
                            final playing = p.data ?? false;
                            return IconButton.filled(
                              icon: Icon(playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                              onPressed: playing ? h.pause : h.play,
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Berikutnya',
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: h.skipToNext,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Garis progres tipis; hanya widget ini yang dibangun ulang saat posisi maju.
class _MiniProgress extends StatefulWidget {
  const _MiniProgress({required this.player});
  final Player player;

  @override
  State<_MiniProgress> createState() => _MiniProgressState();
}

class _MiniProgressState extends State<_MiniProgress> {
  late final Stream<double> _stream = widget.player.stream.position
      .map(_frac)
      .distinct((a, b) => (a - b).abs() < 0.002);

  double _frac(Duration p) {
    final d = widget.player.state.duration.inMilliseconds;
    return d <= 0 ? 0.0 : (p.inMilliseconds / d).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grad = context.mab.gradient ?? [cs.primary, cs.primary];
    return SizedBox(
      height: 3,
      child: StreamBuilder<double>(
        stream: _stream,
        initialData: _frac(widget.player.state.position),
        builder: (_, s) => Stack(children: [
          Positioned.fill(child: ColoredBox(color: cs.outlineVariant)),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (s.data ?? 0).clamp(0.0, 1.0).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: grad.length > 1 ? grad : [grad.first, grad.first]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
