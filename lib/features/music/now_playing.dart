import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../services/audio_handler.dart';
import 'waveform_seek_bar.dart';

class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key, required this.handler});
  final MabAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final player = handler.player;
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        final seed = (item?.id ?? '').hashCode;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _AlbumArt(seed: seed),
            const SizedBox(height: 16),
            Text(item?.title ?? 'Nothing playing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (_, pos) => StreamBuilder<Duration>(
                stream: player.stream.duration,
                initialData: player.state.duration,
                builder: (_, dur) => WaveformSeekBar(
                  position: pos.data ?? Duration.zero,
                  duration: dur.data ?? Duration.zero,
                  seed: seed,
                  onSeek: handler.seek,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _Controls(handler: handler),
          ]),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.handler});
  final MabAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snap) {
        final s = snap.data;
        final shuffleOn = s?.shuffleMode == AudioServiceShuffleMode.all;
        final repeat = s?.repeatMode ?? AudioServiceRepeatMode.none;
        final playing = s?.playing ?? false;
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: Icon(Icons.shuffle_rounded, color: shuffleOn ? primary : null),
            onPressed: () => handler.setShuffleMode(
                shuffleOn ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
          ),
          IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: handler.skipToPrevious),
          IconButton.filled(
            iconSize: 40,
            icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: playing ? handler.pause : handler.play,
          ),
          IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: handler.skipToNext),
          IconButton(
            icon: Icon(
              repeat == AudioServiceRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: repeat == AudioServiceRepeatMode.none ? null : primary,
            ),
            onPressed: () => handler.setRepeatMode(switch (repeat) {
              AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
              AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
              _ => AudioServiceRepeatMode.none,
            }),
          ),
        ]);
      },
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) {
    final hue = (seed.abs() % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.6, 0.35).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 50) % 360, 0.6, 0.2).toColor();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
            ),
          ),
          child: const Center(
              child: Icon(Icons.music_note_rounded, size: 72, color: Colors.white70)),
        ),
      ),
    );
  }
}
