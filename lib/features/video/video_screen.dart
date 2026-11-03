import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/models/media_entry.dart';
import '../../providers.dart';
import 'video_player_page.dart';

class VideoScreen extends ConsumerWidget {
  const VideoScreen({super.key});

  void _open(BuildContext context, MediaEntry e) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => VideoPlayerPage(entry: e)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(videoLibraryProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.play_circle_outline_rounded),
        label: const Text('Buka file'),
        onPressed: () async {
          final r = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: const ['mp4', 'mkv', 'avi', 'webm'],
          );
          final path = r?.path;
          if (path == null || !context.mounted) return;
          _open(
            context,
            MediaEntry(
              path: path,
              title: p.basenameWithoutExtension(path),
              kind: MediaKind.video,
            ),
          );
        },
      ),
      body: items.isEmpty
          ? Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Tambah folder video'),
                onPressed: () => ref.read(libraryProvider.notifier).addFolder(),
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemExtent: 64,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.movie_rounded),
                title: Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.extension(items[i].path).toUpperCase().replaceAll('.', '')),
                onTap: () => _open(context, items[i]),
              ),
            ),
    );
  }
}
