import 'dart:async';
import 'dart:io';

import '../data/services/json_store.dart';
import 'audio_handler.dart';

/// Mengingat antrean, lagu, dan posisi terakhir, lalu memulihkannya saat
/// aplikasi dibuka (dalam keadaan jeda). Penulisan jarang: antrean hanya saat
/// berubah, posisi tiap 10 dtk saat main, saat jeda, dan saat ganti lagu.
class PlaybackMemory {
  PlaybackMemory(this._h, this._store);

  final MabAudioHandler _h;
  final JsonStore _store;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _timer;
  bool _restoring = false;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _restore();
    _subs.add(_h.queue.listen((q) {
      if (_restoring || q.isEmpty) return;
      unawaited(_store.write('queue', [for (final m in q) m.id]));
    }));
    _subs.add(_h.player.stream.playlist.listen((_) => _saveLast()));
    _subs.add(_h.player.stream.playing.listen((playing) {
      if (!playing) _saveLast();
    }));
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_h.player.state.playing) _saveLast();
    });
  }

  void _saveLast() {
    if (_restoring || _h.queue.value.isEmpty) return;
    unawaited(_store.write('last', {
      'index': _h.player.state.playlist.index,
      'ms': _h.player.state.position.inMilliseconds,
    }));
  }

  Future<void> _restore() async {
    try {
      final q = await _store.read('queue');
      final last = await _store.read('last');
      if (q is! List || q.isEmpty) return;
      final paths = q.whereType<String>().toList();
      var idx = 0;
      var ms = 0;
      if (last is Map) {
        idx = (last['index'] as num?)?.toInt() ?? 0;
        ms = (last['ms'] as num?)?.toInt() ?? 0;
      }
      if (idx < 0 || idx >= paths.length) idx = 0;
      if (!File(paths[idx]).existsSync()) return;
      _restoring = true;
      await _h.restoreQueue(paths, index: idx);
      if (ms > 1000) {
        await _h.player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 3));
        await _h.seek(Duration(milliseconds: ms));
      }
    } catch (_) {
      // Gagal memulihkan: mulai kosong saja.
    } finally {
      _restoring = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
  }
}
