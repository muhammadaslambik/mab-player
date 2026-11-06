import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/themed_scope.dart';
import '../../data/models/media_entry.dart';
import '../../data/repositories/playlist_repo.dart';
import '../../providers.dart';
import 'playlist_actions.dart';
import 'playlist_providers.dart';

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  Future<Playlist?> _load() async {
    final lists = await ref.read(playlistRepoProvider).all();
    for (final p in lists) {
      if (p.id == widget.playlistId) return p;
    }
    return null;
  }

  void _refresh() => setState(() {});

  Future<void> _rename(Playlist pl) async {
    final name = await askPlaylistName(context, title: 'Ganti nama', initial: pl.name);
    if (name == null) return;
    await ref.read(playlistRepoProvider).rename(pl.id, name);
    if (mounted) _refresh();
  }

  Future<void> _delete(Playlist pl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('Hapus playlist "${pl.name}"? Lagunya tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(playlistRepoProvider).delete(pl.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final byPath = {for (final e in ref.watch(audioLibraryProvider)) e.path: e};
    final handler = ref.read(audioHandlerProvider);

    // ThemedScope: halaman ini di-push di atas navigator, jadi tema dipasang ulang.
    return ThemedScope(
      child: Backdrop(
        child: FutureBuilder<Playlist?>(
          future: _load(),
          builder: (context, snap) {
            final pl = snap.data;
            if (pl == null) {
              return Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(backgroundColor: Colors.transparent),
                body: Center(
                  child: snap.connectionState == ConnectionState.done
                      ? const Text('Playlist tidak ditemukan')
                      : const CircularProgressIndicator(),
                ),
              );
            }

            final entries = pl.paths.map((p) => byPath[p]).whereType<MediaEntry>().toList();

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  if (entries.isNotEmpty)
                    IconButton(
                      tooltip: 'Putar semua',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => handler.setQueue(entries),
                    ),
                  IconButton(
                    tooltip: 'Ganti nama',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _rename(pl),
                  ),
                  IconButton(
                    tooltip: 'Hapus playlist',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(pl),
                  ),
                ],
              ),
              body: entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Playlist masih kosong.\nDi tab Music, buka menu titik tiga di samping lagu untuk menambahkan.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemExtent: 56,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return ListTile(
                          leading: const Icon(Icons.music_note_rounded),
                          title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: 'Keluarkan dari playlist',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () async {
                              await ref.read(playlistRepoProvider).removeTrack(pl.id, e.path);
                              if (mounted) _refresh();
                            },
                          ),
                          onTap: () => handler.setQueue(entries, index: i),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }
}
