import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/mab_theme.dart';
import '../../services/audio_handler.dart';
import '../settings/settings_provider.dart';
import 'album_art.dart';
import 'lyrics_view.dart';
import 'waveform_seek_bar.dart';

class NowPlaying extends ConsumerWidget {
  const NowPlaying({super.key, required this.handler, this.big = false});
  final MabAudioHandler handler;

  /// Versi besar (layout Stage / pemutar penuh): cover lebih besar, lirik 5 baris.
  final bool big;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(appSettingsProvider);
    return StreamBuilder<MediaItem?>(
      stream: handler.trackInfo,
      initialData: handler.mediaItem.value,
      builder: (context, snap) {
        final item = snap.data;
        final artist = item?.artist;
        final seed = (item?.id ?? '').hashCode;
        final text = Theme.of(context).textTheme;
        return Padding(
          padding: EdgeInsets.all(big ? 28 : 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Glow(
              child: ValueListenableBuilder<Uint8List?>(
                valueListenable: handler.cover,
                builder: (_, cover, _) => AlbumArt(
                  style: st.art,
                  seed: seed,
                  cover: cover,
                  player: handler.player,
                  size: big ? 340 : 260,
                  anim: st.anim,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(item?.id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item?.title ?? 'Nothing playing',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge),
                  if (artist != null) ...[
                    const SizedBox(height: 4),
                    Text(artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium),
                  ],
                ],
              ),
            ),
            LyricsView(handler: handler, radius: big ? 2 : 1),
            const SizedBox(height: 12),
            WaveformSeekBar(
              player: handler.player,
              seed: seed,
              onSeek: handler.seek,
              style: st.wave,
            ),
            const SizedBox(height: 8),
            _Controls(handler: handler),
            const SizedBox(height: 4),
            _Tools(handler: handler),
          ]),
        );
      },
    );
  }
}

/// Cahaya lembut di belakang cover; warnanya berubah halus mengikuti aksen.
class _Glow extends StatelessWidget {
  const _Glow({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strong = context.mab.glow;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [cs.primary.withAlpha(strong ? 70 : 36), cs.primary.withAlpha(0)],
          radius: 0.75,
        ),
      ),
      child: child,
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.handler});
  final MabAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tk = context.mab;
    final playGrad = tk.gradient ?? [cs.primary, Color.lerp(cs.primary, cs.secondary, 0.55)!];
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snap) {
        final s = snap.data;
        final shuffleOn = s?.shuffleMode == AudioServiceShuffleMode.all;
        final repeat = s?.repeatMode ?? AudioServiceRepeatMode.none;
        final playing = s?.playing ?? false;
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: Icon(Icons.shuffle_rounded, color: shuffleOn ? cs.primary : null),
            onPressed: () => handler.setShuffleMode(
                shuffleOn ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
          ),
          IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: handler.skipToPrevious),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: playGrad.length > 1 ? playGrad : [playGrad.first, playGrad.first],
              ),
              boxShadow: tk.glow
                  ? [BoxShadow(color: cs.primary.withAlpha(110), blurRadius: 18)]
                  : null,
            ),
            child: IconButton(
              iconSize: 40,
              color: cs.onPrimary,
              onPressed: playing ? handler.pause : handler.play,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(playing),
                ),
              ),
            ),
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
              color: repeat == AudioServiceRepeatMode.none ? null : cs.primary,
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

/// Sleep timer, equalizer, dan volume.
class _Tools extends StatelessWidget {
  const _Tools({required this.handler});
  final MabAudioHandler handler;

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelMedium;
    return Row(children: [
      ValueListenableBuilder<DateTime?>(
        valueListenable: handler.sleepAt,
        builder: (context, at, _) => PopupMenuButton<int>(
          tooltip: 'Sleep timer',
          onSelected: (m) => handler.setSleepTimer(m == 0 ? null : Duration(minutes: m)),
          itemBuilder: (_) => [
            for (final m in const [15, 30, 45, 60])
              PopupMenuItem(value: m, child: Text('$m menit')),
            if (at != null) const PopupMenuItem(value: 0, child: Text('Matikan timer')),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bedtime_outlined, size: 20, color: at == null ? null : cs.primary),
              if (at != null) ...[
                const SizedBox(width: 4),
                Text(_hm(at), style: small?.copyWith(color: cs.primary)),
              ],
            ]),
          ),
        ),
      ),
      ValueListenableBuilder<String>(
        valueListenable: handler.eq,
        builder: (context, id, _) => PopupMenuButton<String>(
          tooltip: 'Equalizer',
          initialValue: id,
          onSelected: (v) async {
            final ok = await handler.setEq(v);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Equalizer tidak tersedia di perangkat ini')));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'flat', child: Text('Equalizer: mati')),
            PopupMenuItem(value: 'bass', child: Text('Bass boost')),
            PopupMenuItem(value: 'treble', child: Text('Treble')),
            PopupMenuItem(value: 'vocal', child: Text('Vokal')),
            PopupMenuItem(value: 'loud', child: Text('Loudness')),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.equalizer_rounded,
                size: 20, color: id == 'flat' ? null : cs.primary),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(child: _VolumeBar(handler: handler)),
    ]);
  }
}

class _VolumeBar extends StatelessWidget {
  const _VolumeBar({required this.handler});
  final MabAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final player = handler.player;
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snap) {
        final v = ((snap.data ?? 100) / 100).clamp(0.0, 1.0).toDouble();
        return Row(children: [
          Icon(
            v == 0
                ? Icons.volume_off_rounded
                : v < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            size: 18,
          ),
          Expanded(
            child: Slider(value: v, onChanged: (x) => player.setVolume(x * 100)),
          ),
        ]);
      },
    );
  }
}
