import '../services/json_store.dart';

class Playlist {
  const Playlist({required this.id, required this.name, required this.paths});

  final String id;
  final String name;
  final List<String> paths;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'paths': paths};

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        paths: ((j['paths'] as List?) ?? const []).cast<String>().toList(),
      );

  Playlist copyWith({String? name, List<String>? paths}) =>
      Playlist(id: id, name: name ?? this.name, paths: paths ?? this.paths);
}

/// Playlist disimpan sebagai daftar jalur file di JSON privat aplikasi.
/// Lagu yang filenya sudah tidak ada di pustaka dilewati saat ditampilkan.
class PlaylistRepo {
  PlaylistRepo(this._store);
  final JsonStore _store;

  static const _key = 'playlists';

  Future<List<Playlist>> all() async {
    final r = await _store.read(_key);
    if (r is! List) return <Playlist>[];
    return [
      for (final e in r) Playlist.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<void> _save(List<Playlist> list) =>
      _store.write(_key, list.map((e) => e.toJson()).toList());

  Future<Playlist> create(String name) async {
    final list = await all();
    final trimmed = name.trim();
    final p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed.isEmpty ? 'Playlist' : trimmed,
      paths: const [],
    );
    list.add(p);
    await _save(list);
    return p;
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final list = await all();
    final i = list.indexWhere((p) => p.id == id);
    if (i < 0) return;
    list[i] = list[i].copyWith(name: trimmed);
    await _save(list);
  }

  Future<void> delete(String id) async {
    final list = await all();
    list.removeWhere((p) => p.id == id);
    await _save(list);
  }

  /// Mengembalikan false bila lagu sudah ada di playlist itu.
  Future<bool> addTrack(String id, String path) async {
    final list = await all();
    final i = list.indexWhere((p) => p.id == id);
    if (i < 0) return false;
    if (list[i].paths.contains(path)) return false;
    list[i] = list[i].copyWith(paths: [...list[i].paths, path]);
    await _save(list);
    return true;
  }

  Future<void> removeTrack(String id, String path) async {
    final list = await all();
    final i = list.indexWhere((p) => p.id == id);
    if (i < 0) return;
    list[i] = list[i].copyWith(paths: [...list[i].paths]..remove(path));
    await _save(list);
  }
}
