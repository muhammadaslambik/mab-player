import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/media_entry.dart';
import '../../providers.dart';
import '../playlists/playlist_actions.dart';
import 'accent_scope.dart';
import 'now_playing.dart';

enum _Sort { scan, titleAsc, titleDesc }

enum _Act { next, queue, playlist }

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Sort _sort = _Sort.scan;

  // Cache hasil cari/urut: tidak diurutkan ulang tiap build.
  List<MediaEntry>? _srcCache;
  String _qCache = '';
  _Sort _sortCache = _Sort.scan;
  List<MediaEntry> _viewCache = const [];

  // Hanya berubah bila lagu aktif ganti (bukan tiap update durasi/tag).
  late final Stream<String?> _ids =
      ref.read(audioHandlerProvider).mediaItem.map((m) => m?.id).distinct();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MediaEntry> _view(List<MediaEntry> items) {
    if (identical(items, _srcCache) && _query == _qCache && _sort == _sortCache) {
      return _viewCache;
    }
    final q = _query.trim().toLowerCase();
    var out = q.isEmpty
        ? items
        : items.where((e) => e.title.toLowerCase().contains(q)).toList();
    if (_sort != _Sort.scan) {
      out = [...out]..sort((a, b) {
          final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return _sort == _Sort.titleAsc ? c : -c;
        });
    }
    _srcCache = items;
    _qCache = _query;
    _sortCache = _sort;
    return _viewCache = out;
  }

  void _toast(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1400)));
  }

  void _onAction(_Act a, MediaEntry e) {
    final h = ref.read(audioHandlerProvider);
    switch (a) {
      case _Act.next:
        h.enqueue(e, next: true);
        _toast('Diputar berikutnya');
      case _Act.queue:
        h.enqueue(e);
        _toast('Ditambahkan ke antrean');
      case _Act.playlist:
        showAddToPlaylist(context, ref, e);
    }
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cari lagu',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Bersihkan',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24))),
              ),
            ),
          ),
          PopupMenuButton<_Sort>(
            tooltip: 'Urutkan',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.scan, child: Text('Bawaan')),
              PopupMenuItem(value: _Sort.titleAsc, child: Text('Judul A–Z')),
              PopupMenuItem(value: _Sort.titleDesc, child: Text('Judul Z–A')),
            ],
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(audioLibraryProvider);
    final loading = ref.watch(libraryProvider).isLoading;
    final handler = ref.watch(audioHandlerProvider);

    if (all.isEmpty) {
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

    final items = _view(all);

    final list = items.isEmpty
        ? const Center(child: Text('Tidak ada lagu yang cocok'))
        : StreamBuilder<String?>(
            stream: _ids,
            builder: (context, snap) {
              final currentId = snap.data;
              final accent = Theme.of(context).colorScheme.primary;
              return ListView.builder(
                itemCount: items.length,
                itemExtent: 60,
                itemBuilder: (_, i) {
                  final e = items[i];
                  return _TrackRow(
                    entry: e,
                    active: e.path == currentId,
                    accent: accent,
                    // Antrean = daftar yang sedang tampil (hasil cari/urut).
                    onTap: () => handler.setQueue(items, index: i),
                    onAction: (a) => _onAction(a, e),
                  );
                },
              );
            },
          );

    final queue = Column(children: [
      _header(),
      Expanded(child: list),
    ]);

    return AccentScope(
      handler: handler,
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth >= 800) {
          return Row(children: [
            SizedBox(
                width: 400,
                child: Center(
                    child: SingleChildScrollView(child: NowPlaying(handler: handler)))),
            const VerticalDivider(width: 1),
            Expanded(child: queue),
          ]);
        }
        return Column(children: [
          NowPlaying(handler: handler),
          const Divider(height: 1),
          Expanded(child: queue),
        ]);
      }),
    );
  }
}

/// Baris lagu yang ringan (tanpa ListTile).
class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.entry,
    required this.active,
    required this.accent,
    required this.onTap,
    required this.onAction,
  });

  final MediaEntry entry;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final ValueChanged<_Act> onAction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(children: [
          Icon(active ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
              color: active ? accent : null),
          const SizedBox(width: 16),
          Expanded(
            child: Text(entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: active ? accent : null)),
          ),
          PopupMenuButton<_Act>(
            tooltip: 'Opsi',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: onAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Act.next, child: Text('Putar berikutnya')),
              PopupMenuItem(value: _Act.queue, child: Text('Tambah ke antrean')),
              PopupMenuItem(value: _Act.playlist, child: Text('Tambah ke playlist')),
            ],
          ),
        ]),
      ),
    );
  }
}
