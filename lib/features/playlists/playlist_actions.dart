import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/media_entry.dart';
import '../../data/repositories/playlist_repo.dart';
import 'playlist_providers.dart';

/// Dialog satu kolom untuk nama playlist. Mengembalikan null bila dibatalkan.
Future<String?> askPlaylistName(
  BuildContext context, {
  String title = 'Playlist baru',
  String initial = '',
}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nama playlist'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Simpan')),
      ],
    ),
  );
  final t = r?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Pilih playlist (atau buat baru) lalu tambahkan lagu [e] ke dalamnya.
Future<void> showAddToPlaylist(BuildContext context, WidgetRef ref, MediaEntry e) async {
  final repo = ref.read(playlistRepoProvider);
  final lists = await repo.all();
  if (!context.mounted) return;

  final choice = await showDialog<Object>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Tambah ke playlist'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'new'),
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.add_rounded),
            title: Text('Playlist baru'),
          ),
        ),
        for (final p in lists)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p.paths.length} lagu'),
            ),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  final Playlist target;
  if (choice == 'new') {
    final name = await askPlaylistName(context);
    if (name == null || !context.mounted) return;
    target = await repo.create(name);
  } else if (choice is Playlist) {
    target = choice;
  } else {
    return;
  }

  final added = await repo.addTrack(target.id, e.path);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(added
          ? 'Ditambahkan ke "${target.name}"'
          : 'Sudah ada di "${target.name}"'),
      duration: const Duration(seconds: 2),
    ));
}
