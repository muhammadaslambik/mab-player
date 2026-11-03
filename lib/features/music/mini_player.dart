import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(audioHandlerProvider);
    return StreamBuilder<MediaItem?>(
      stream: h.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) return const SizedBox.shrink();
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.music_note_rounded),
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: StreamBuilder<bool>(
              stream: h.player.stream.playing,
              initialData: h.player.state.playing,
              builder: (_, p) {
                final playing = p.data ?? false;
                return IconButton(
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  onPressed: playing ? h.pause : h.play,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
