import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/format.dart';
import '../../data/models/media_entry.dart';
import '../../providers.dart';
import '../video/video_player_page.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  void _refresh() => setState(() {});

  void _play(Map<String, dynamic> m) {
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

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);
    final repo = ref.read(historyProvider);
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('Folder', style: titleStyle),
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
      Row(children: [
        Text('Riwayat', style: titleStyle),
        const Spacer(),
        TextButton(
          onPressed: () async {
            if (await _confirm('Hapus seluruh riwayat?')) {
              await repo.clearHistory();
              _refresh();
            }
          },
          child: const Text('Bersihkan'),
        ),
      ]),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.history(),
        builder: (_, s) => Column(children: [
          for (final m in s.data ?? const <Map<String, dynamic>>[])
            ListTile(
              dense: true,
              leading: Icon(m['kind'] == 'video' ? Icons.movie_rounded : Icons.music_note_rounded),
              title: Text(m['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Lanjut dari ${fmt(Duration(milliseconds: m['positionMs'] as int))}'),
              trailing: IconButton(
                tooltip: 'Hapus dari riwayat',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () async {
                  await repo.removeHistory(m['path'] as String);
                  _refresh();
                },
              ),
              onTap: () => _play(m),
            ),
        ]),
      ),
      const Divider(height: 32),
      Row(children: [
        Text('Bookmark', style: titleStyle),
        const Spacer(),
        TextButton(
          onPressed: () async {
            if (await _confirm('Hapus semua bookmark?')) {
              await repo.clearBookmarks();
              _refresh();
            }
          },
          child: const Text('Bersihkan'),
        ),
      ]),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.bookmarks(),
        builder: (_, s) => Column(children: [
          for (final m in s.data ?? const <Map<String, dynamic>>[])
            ListTile(
              dense: true,
              leading: const Icon(Icons.bookmark_rounded),
              title: Text(m['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(fmt(Duration(milliseconds: m['positionMs'] as int))),
              trailing: IconButton(
                tooltip: 'Hapus bookmark',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () async {
                  await repo.removeBookmark(m['path'] as String, m['positionMs'] as int);
                  _refresh();
                },
              ),
              onTap: () => _play(m),
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
