import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/media_entry.dart';
import '../../providers.dart';
import 'now_playing.dart';

enum _Sort { scan, titleAsc, titleDesc }

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Sort _sort = _Sort.scan;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Daftar yang tampil: disaring oleh pencarian, lalu diurutkan.
  List<MediaEntry> _view(List<MediaEntry> items) {
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
    return out;
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
        : StreamBuilder<MediaItem?>(
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
                    leading: Icon(
                        active ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                        color: active ? Theme.of(context).colorScheme.primary : null),
                    title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: active,
                    // Antrean = daftar yang sedang tampil (hasil cari/urut).
                    onTap: () => handler.setQueue(items, index: i),
                  );
                },
              );
            },
          );

    final queue = Column(children: [
      _header(),
      Expanded(child: list),
    ]);

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
