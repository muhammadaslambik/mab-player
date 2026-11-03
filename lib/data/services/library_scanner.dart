import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/media_entry.dart';

class LibraryScanner {
  static const audioExt = {'.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg'};
  static const videoExt = {'.mp4', '.mkv', '.avi', '.webm'};

  Future<List<MediaEntry>> scan(Iterable<String> roots) async {
    final found = <String, MediaEntry>{};
    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      try {
        await for (final e
            in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
          if (e is! File) continue;
          final ext = p.extension(e.path).toLowerCase();
          final kind = audioExt.contains(ext)
              ? MediaKind.audio
              : videoExt.contains(ext)
                  ? MediaKind.video
                  : null;
          if (kind == null) continue;
          found[e.path] = MediaEntry(
            path: e.path,
            title: p.basenameWithoutExtension(e.path),
            kind: kind,
          );
        }
      } catch (_) {}
    }
    return found.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  static Future<List<String>> defaultRoots() async {
    if (Platform.isAndroid) {
      return const [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/DCIM',
      ];
    }
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null) return const [];
    return [
      p.join(home, 'Music'),
      p.join(home, 'Videos'),
      p.join(home, 'Movies'),
      p.join(home, 'Downloads'),
    ];
  }
}
