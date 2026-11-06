import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio_handler.dart';
import '../../services/lyrics.dart';

Future<void> showLyricsSheet(BuildContext context, MabAudioHandler handler) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.72,
        child: LyricsList(handler: handler),
      ),
    );

/// Daftar lirik lengkap. Tersinkron: baris aktif disorot dan mengikuti lagu;
/// teks biasa: tampil apa adanya.
class LyricsList extends StatelessWidget {
  const LyricsList({super.key, required this.handler});
  final MabAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Lyrics>(
      valueListenable: handler.lyrics,
      builder: (context, l, _) {
        if (l.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tidak ada lirik untuk lagu ini.\n\nTaruh file .lrc (tersinkron) atau .txt '
                'dengan nama yang sama persis di folder yang sama dengan lagunya.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!l.synced) return _Plain(lines: l.lines);
        return _SyncedList(key: ValueKey(l), handler: handler, lines: l.lines);
      },
    );
  }
}

class _Plain extends StatelessWidget {
  const _Plain({required this.lines});
  final List<LyricLine> lines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: lines.length,
      itemBuilder: (_, i) => lines[i].text.isEmpty
          ? const SizedBox(height: 14)
          : Text(lines[i].text, textAlign: TextAlign.center, style: style),
    );
  }
}

class _SyncedList extends StatefulWidget {
  const _SyncedList({super.key, required this.handler, required this.lines});
  final MabAudioHandler handler;
  final List<LyricLine> lines;

  @override
  State<_SyncedList> createState() => _SyncedListState();
}

class _SyncedListState extends State<_SyncedList> {
  static const _extent = 48.0;
  final _c = ScrollController();
  StreamSubscription<int>? _sub;
  int _i = -1;

  @override
  void initState() {
    super.initState();
    final p = widget.handler.player;
    _i = lyricIndexAt(widget.lines, p.state.position);
    _sub = p.stream.position
        .map((d) => lyricIndexAt(widget.lines, d))
        .distinct()
        .listen((i) {
      if (!mounted) return;
      setState(() => _i = i);
      _follow();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(jump: true));
  }

  void _follow({bool jump = false}) {
    if (!_c.hasClients || _i < 0) return;
    final pos = _c.position;
    final target = math
        .min(math.max(_i * _extent - pos.viewportDimension / 2 + _extent / 2, 0.0),
            pos.maxScrollExtent)
        .toDouble();
    if (jump) {
      _c.jumpTo(target);
    } else {
      _c.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListView.builder(
      controller: _c,
      itemExtent: _extent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.lines.length,
      itemBuilder: (_, k) {
        final active = k == _i;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.handler.seek(widget.lines[k].at),
          child: Center(
            child: Text(
              widget.lines[k].text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: active
                  ? text.titleMedium?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w700)
                  : text.bodyLarge?.copyWith(color: cs.onSurface.withAlpha(150)),
            ),
          ),
        );
      },
    );
  }
}
