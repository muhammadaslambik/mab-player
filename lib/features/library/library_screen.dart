import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/format.dart';
import '../../data/models/media_entry.dart';
import '../../providers.dart';
import '../video/video_player_page.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _play(BuildContext context, WidgetRef ref, Map<String, dynamic> m) {
    final e = MediaEntry.fromJson(m);
    final start = Duration(milliseconds: (m['positionMs'] as int?) ?? 0);
    if (e.kind == MediaKind.video) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerPage(entry: e, startAt: start)),
      );
    } else {
      ref.read(audioHandlerProvider).setQueue([e]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);
    final repo = ref.read(historyProvider);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('Folder', style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        IconButton(
            tooltip: 'Scan ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: notifier.rescan),
        IconButton(
            tooltip: 'Tambah folder',
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: notifier.addFolder),
      ]),
      if (lib.isLoading) const LinearProgressIndicator(),
      FutureBuilder<List<String>>(
        future: notifier.roots(),
        builder: (_, s) => Column(children: [
          for (final r in s.data ?? const <String>[])
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_rounded),
              title: Text(r),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FolderPage(root: r)),
              ),
            ),
        ]),
      ),
      const Divider(height: 32),
      Text('Riwayat', style: Theme.of(context).textTheme.titleMedium),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.history(),
        builder: (_, s) => Column(children: [
          for (final m in s.data ?? const <Map<String, dynamic>>[])
            ListTile(
              dense: true,
              leading: Icon(m['kind'] == 'video' ? Icons.movie_rounded : Icons.music_note_rounded),
              title: Text(m['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Lanjut dari ${fmt(Duration(milliseconds: m['positionMs'] as int))}'),
              onTap: () => _play(context, ref, m),
            ),
        ]),
      ),
      const Divider(height: 32),
      Text('Bookmark', style: Theme.of(context).textTheme.titleMedium),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.bookmarks(),
        builder: (_, s) => Column(children: [
          for (final m in s.data ?? const <Map<String, dynamic>>[])
            ListTile(
              dense: true,
              leading: const Icon(Icons.bookmark_rounded),
              title: Text(m['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(fmt(Duration(milliseconds: m['positionMs'] as int))),
              onTap: () => _play(context, ref, m),
            ),
        ]),
      ),
    ]);
  }
}

/// Daftar isi satu folder (dari cache scan, tanpa scan ulang).
class FolderPage extends ConsumerWidget {
  const FolderPage({super.key, required this.root});

  final String root;

  Future<void> _open(BuildContext context, WidgetRef ref, MediaEntry e) async {
    if (e.kind == MediaKind.video) {
      final start = await ref.read(historyProvider).lastPosition(e.path);
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerPage(entry: e, startAt: start)),
      );
    } else {
      ref.read(audioHandlerProvider).setQueue([e]);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Memutar: ${e.title}'),
          duration: const Duration(seconds: 2),
        ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(libraryProvider).value ?? const <MediaEntry>[];
    final items = all.where((e) => p.isWithin(root, e.path)).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(root, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tidak ada media di folder ini.\nCoba "Scan ulang" di tab Library.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemExtent: 56,
              itemBuilder: (_, i) {
                final e = items[i];
                return ListTile(
                  leading: Icon(e.kind == MediaKind.video
                      ? Icons.movie_rounded
                      : Icons.music_note_rounded),
                  title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(context, ref, e),
                );
              },
            ),
    );
  }
}