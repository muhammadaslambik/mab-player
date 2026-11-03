import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'now_playing.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(audioLibraryProvider);
    final loading = ref.watch(libraryProvider).isLoading;
    final handler = ref.watch(audioHandlerProvider);

    if (items.isEmpty) {
      return Center(
        child: loading
            ? const CircularProgressIndicator()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Belum ada musik ditemukan'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Tambah folder musik'),
                  onPressed: () => ref.read(libraryProvider.notifier).addFolder(),
                ),
                TextButton(
                  onPressed: () => ref.read(libraryProvider.notifier).rescan(),
                  child: const Text('Scan folder bawaan'),
                ),
              ]),
      );
    }

    final queue = StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snap) {
        final currentId = snap.data?.id;
        return ListView.builder(
          itemCount: items.length,
          itemExtent: 60,
          itemBuilder: (_, i) {
            final e = items[i];
            final active = e.path == currentId;
            return ListTile(
              leading: Icon(active ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                  color: active ? Theme.of(context).colorScheme.primary : null),
              title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: active,
              onTap: () => handler.setQueue(items, index: i),
            );
          },
        );
      },
    );

    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 800) {
        return Row(children: [
          SizedBox(
              width: 400,
              child: Center(child: SingleChildScrollView(child: NowPlaying(handler: handler)))),
          const VerticalDivider(width: 1),
          Expanded(child: queue),
        ]);
      }
      return Column(children: [
        NowPlaying(handler: handler),
        const Divider(height: 1),
        Expanded(child: queue),
      ]);
    });
  }
}
