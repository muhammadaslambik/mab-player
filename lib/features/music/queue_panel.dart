import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../services/audio_handler.dart';

Future<void> showQueueSheet(BuildContext context, MabAudioHandler handler) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.72,
        child: QueueList(handler: handler),
      ),
    );

/// Antrean yang sedang diputar; ketuk untuk loncat ke lagu itu.
class QueueList extends StatefulWidget {
  const QueueList({super.key, required this.handler});
  final MabAudioHandler handler;

  @override
  State<QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<QueueList> {
  static const _extent = 52.0;
  late final ScrollController _c;

  @override
  void initState() {
    super.initState();
    final id = widget.handler.mediaItem.value?.id;
    final q = widget.handler.queue.value;
    final idx = id == null ? 0 : math.max(0, q.indexWhere((m) => m.id == id));
    _c = ScrollController(initialScrollOffset: math.max(0.0, idx * _extent - 104));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.handler;
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<List<MediaItem>>(
      stream: h.queue,
      initialData: h.queue.value,
      builder: (context, qs) {
        final q = qs.data ?? const <MediaItem>[];
        if (q.isEmpty) return const Center(child: Text('Antrean kosong'));
        return StreamBuilder<MediaItem?>(
          stream: h.trackInfo,
          initialData: h.mediaItem.value,
          builder: (context, ids) {
            final cur = ids.data?.id;
            return ListView.builder(
              controller: _c,
              itemExtent: _extent,
              itemCount: q.length,
              itemBuilder: (_, i) {
                final active = q[i].id == cur;
                return InkWell(
                  onTap: () => h.skipToQueueItem(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      SizedBox(
                        width: 32,
                        child: active
                            ? Icon(Icons.graphic_eq_rounded, size: 18, color: cs.primary)
                            : Text('${i + 1}',
                                style: TextStyle(color: cs.onSurface.withAlpha(130))),
                      ),
                      Expanded(
                        child: Text(
                          q[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? cs.primary : null,
                            fontWeight: active ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
