import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../core/platform.dart';
import '../../core/theme/mab_theme.dart';
import '../../data/models/media_entry.dart';
import '../../providers.dart';
import '../playlists/playlist_actions.dart';
import '../settings/appearance_sheet.dart';
import '../settings/settings_provider.dart';
import 'accent_scope.dart';
import 'eq_bars.dart';
import 'mini_player.dart';
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
      ref.read(audioHandlerProvider).trackInfo.map((m) => m?.id).distinct();

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

  Widget _header(int total) {
    final tk = context.mab;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari di $total lagu',
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
        IconButton(
          tooltip: 'Tampilan',
          icon: const Icon(Icons.palette_outlined),
          onPressed: () => showAppearanceSheet(context),
        ),
      ]),
    );
  }

  Widget _panel(BuildContext context, Widget child) {
    final tk = context.mab;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tk.panel,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: tk.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Center(child: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(audioLibraryProvider);
    final loading = ref.watch(libraryProvider).isLoading;
    final handler = ref.watch(audioHandlerProvider);
    final layoutSetting = ref.watch(appSettingsProvider.select((s) => s.layout));
    final anim = ref.watch(appSettingsProvider.select((s) => s.anim));

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
            initialData: handler.mediaItem.value?.id,
            builder: (context, snap) {
              final currentId = snap.data;
              final accent = Theme.of(context).colorScheme.primary;
              return ListView.builder(
                itemCount: items.length,
                itemExtent: 64,
                itemBuilder: (_, i) {
                  final e = items[i];
                  return _TrackRow(
                    entry: e,
                    active: e.path == currentId,
                    accent: accent,
                    player: handler.player,
                    anim: anim,
                    // Antrean = daftar yang sedang tampil (hasil cari/urut).
                    onTap: () => handler.setQueue(items, index: i),
                    onAction: (a) => _onAction(a, e),
                  );
                },
              );
            },
          );

    final queue = Column(children: [
      _header(all.length),
      Expanded(child: list),
    ]);

    return AccentScope(
      handler: handler,
      child: LayoutBuilder(builder: (context, box) {
        final mode = resolveLayout(layoutSetting, box.maxWidth, formFactorOf(context));
        if (mode == 'stage') {
          return Row(children: [
            Expanded(child: _panel(context, NowPlaying(handler: handler, big: true))),
            SizedBox(width: 380, child: queue),
          ]);
        }
        if (mode == 'split') {
          return Row(children: [
            SizedBox(width: 410, child: _panel(context, NowPlaying(handler: handler))),
            Expanded(child: queue),
          ]);
        }
        return Column(children: [
          Expanded(child: queue),
          const MiniPlayer(),
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
    required this.player,
    required this.anim,
    required this.onTap,
    required this.onAction,
  });

  final MediaEntry entry;
  final bool active;
  final Color accent;
  final Player player;
  final bool anim;
  final VoidCallback onTap;
  final ValueChanged<_Act> onAction;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? accent.withAlpha(40) : on.withAlpha(14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: active
                  ? EqBars(player: player, color: accent, animate: anim)
                  : Icon(Icons.music_note_rounded, size: 20, color: on.withAlpha(150)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? accent : null,
                fontWeight: active ? FontWeight.w600 : null,
              ),
            ),
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
