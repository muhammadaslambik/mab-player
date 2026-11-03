import '../models/media_entry.dart';
import '../services/json_store.dart';

class HistoryRepo {
  HistoryRepo(this._store);
  final JsonStore _store;

  Future<List<Map<String, dynamic>>> _list(String name) async {
    final r = await _store.read(name);
    return r is List
        ? r.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> history() => _list('history');

  /// Bookmark tanpa duplikat (video yang sama di detik yang sama).
  Future<List<Map<String, dynamic>>> bookmarks() async {
    final seen = <String>{};
    return [
      for (final m in await _list('bookmarks'))
        if (seen.add('${m['path']}|${(m['positionMs'] as int) ~/ 1000}')) m,
    ];
  }

  Future<void> record(MediaEntry e, Duration position) async {
    final list = await history();
    list.removeWhere((m) => m['path'] == e.path);
    list.insert(0, {
      ...e.toJson(),
      'positionMs': position.inMilliseconds,
      'at': DateTime.now().toIso8601String(),
    });
    await _store.write('history', list.take(100).toList());
  }

  Future<Duration> lastPosition(String path) async {
    final list = await history();
    final m = list.where((e) => e['path'] == path);
    return m.isEmpty ? Duration.zero : Duration(milliseconds: m.first['positionMs'] as int);
  }

  Future<void> addBookmark(MediaEntry e, Duration position) async {
    final list = await _list('bookmarks');
    list.removeWhere((m) =>
        m['path'] == e.path && ((m['positionMs'] as int) ~/ 1000) == position.inSeconds);
    list.insert(0, {...e.toJson(), 'positionMs': position.inMilliseconds});
    await _store.write('bookmarks', list.take(200).toList());
  }

  Future<void> removeHistory(String path) async {
    final list = await history();
    list.removeWhere((m) => m['path'] == path);
    await _store.write('history', list);
  }

  /// Hapus bookmark pada video [path] di detik yang sama dengan [positionMs]
  /// (termasuk duplikat lama yang mungkin masih tersimpan).
  Future<void> removeBookmark(String path, int positionMs) async {
    final list = await _list('bookmarks');
    list.removeWhere((m) =>
        m['path'] == path && ((m['positionMs'] as int) ~/ 1000) == positionMs ~/ 1000);
    await _store.write('bookmarks', list);
  }

  Future<void> clearHistory() => _store.write('history', <Object>[]);
  Future<void> clearBookmarks() => _store.write('bookmarks', <Object>[]);
}
