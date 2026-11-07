import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/mab_theme.dart';
import '../../data/models/media_entry.dart';
import '../../providers.dart';
import 'video_player_page.dart';

class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  final _search = TextEditingController();
  String _query = '';

  // Cache hasil cari: tidak disaring ulang tiap build.
  List<MediaEntry>? _srcCache;
  String _qCache = '';
  List<MediaEntry> _viewCache = const [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(MediaEntry e) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => VideoPlayerPage(entry: e)));

  List<MediaEntry> _view(List<MediaEntry> items) {
    if (identical(items, _srcCache) && _query == _qCache) return _viewCache;
    final q = _query.trim().toLowerCase();
    _srcCache = items;
    _qCache = _query;
    return _viewCache =
        q.isEmpty ? items : items.where((e) => e.title.toLowerCase().contains(q)).toList();
  }

  Widget _header(int total) {
    final tk = context.mab;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Cari di $total video',
          isDense: true,
          filled: true,
          fillColor: tk.panel,
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: tk.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: tk.border),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(videoLibraryProvider);
    final items = _view(all);
    final cs = Theme.of(context).colorScheme;
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
          if (path == null || !mounted) return;
          _open(
            MediaEntry(
              path: path,
              title: p.basenameWithoutExtension(path),
              kind: MediaKind.video,
            ),
          );
        },
      ),
      body: all.isEmpty
          ? Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Tambah folder video'),
                onPressed: () => ref.read(libraryProvider.notifier).addFolder(),
              ),
            )
          : Column(children: [
              _header(all.length),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Tidak ada video yang cocok'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemExtent: 64,
                        itemBuilder: (_, i) {
                          final e = items[i];
                          return InkWell(
                            onTap: () => _open(e),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.movie_rounded,
                                      size: 20, color: cs.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.title,
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(
                                        p.extension(e.path).toUpperCase().replaceAll('.', ''),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
