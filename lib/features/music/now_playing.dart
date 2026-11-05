import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../services/audio_handler.dart';
import 'waveform_seek_bar.dart';

class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key, required this.handler});
  final MabAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        final artist = item?.artist;
        final seed = (item?.id ?? '').hashCode;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ValueListenableBuilder<Uint8List?>(
              valueListenable: handler.cover,
              builder: (_, cover, _) => _AlbumArt(seed: seed, cover: cover),
            ),
            const SizedBox(height: 16),
            Text(item?.title ?? 'Nothing playing',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
            if (artist != null) ...[
              const SizedBox(height: 4),
              Text(artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            WaveformSeekBar(player: handler.player, seed: seed, onSeek: handler.seek),
            const SizedBox(height: 8),
            _Controls(handler: handler),
            _SleepButton(handler: handler),
          ]),
        );
      },
    );
  }
}

class _SleepButton extends StatelessWidget {
  const _SleepButton({required this.handler});
  final MabAudioHandler handler;

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: handler.sleepAt,
      builder: (context, at, _) {
        final primary = Theme.of(context).colorScheme.primary;
        return PopupMenuButton<int>(
          tooltip: 'Sleep timer',
          onSelected: (m) => handler.setSleepTimer(m == 0 ? null : Duration(minutes: m)),
          itemBuilder: (_) => [
            for (final m in const [15, 30, 45, 60])
              PopupMenuItem(value: m, child: Text('$m menit')),
            if (at != null) const PopupMenuItem(value: 0, child: Text('Matikan timer')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bedtime_outlined, size: 18, color: at == null ? null : primary),
              const SizedBox(width: 6),
              Text(at == null ? 'Sleep timer' : 'Berhenti ${_hm(at)}',
                  style: Theme.of(context).textTheme.labelMedium),
            ]),
          ),
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
  const _AlbumArt({required this.seed, this.cover});
  final int seed;
  final Uint8List? cover;

  @override
  Widget build(BuildContext context) {
    final hue = (seed.abs() % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.6, 0.35).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 50) % 360, 0.6, 0.2).toColor();
    final art = cover;

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      child: const Center(
          child: Icon(Icons.music_note_rounded, size: 72, color: Colors.white70)),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: art == null
              ? fallback
              : Image.memory(
                  art,
                  fit: BoxFit.cover,
                  cacheWidth: 520, // batasi memori hasil decode
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
