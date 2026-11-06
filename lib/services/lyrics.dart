import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

class LyricLine {
  const LyricLine(this.at, this.text);
  final Duration at;
  final String text;
}

/// Lirik satu lagu. [synced] = ada stempel waktu (.lrc); selain itu teks biasa.
class Lyrics {
  const Lyrics(this.lines, {this.synced = true});
  final List<LyricLine> lines;
  final bool synced;
  bool get isEmpty => lines.isEmpty;
  static const empty = Lyrics(<LyricLine>[]);
}

final _ts = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

/// Parser LRC sederhana: `[mm:ss.xx] teks` (boleh beberapa stempel waktu per baris).
List<LyricLine> parseLrc(String src) {
  final out = <LyricLine>[];
  for (final raw in src.split(RegExp(r'\r?\n'))) {
    final ms = _ts.allMatches(raw).toList();
    if (ms.isEmpty) continue;
    final text = raw.replaceAll(_ts, '').trim();
    for (final m in ms) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final frac = m.group(3);
      var milli = 0;
      if (frac != null) milli = int.parse(frac.padRight(3, '0').substring(0, 3));
      out.add(LyricLine(
        Duration(minutes: min, seconds: sec, milliseconds: milli),
        text.isEmpty ? '♪' : text,
      ));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Indeks baris yang sedang aktif pada posisi [p] (-1 = belum mulai).
int lyricIndexAt(List<LyricLine> lines, Duration p) {
  final t = p + const Duration(milliseconds: 150);
  var lo = 0, hi = lines.length - 1, ans = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].at <= t) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}

/// Cari lirik di samping file lagu: `nama.lrc` (tersinkron), lalu `nama.txt`
/// (teks biasa; bila ternyata berstempel waktu tetap dibaca sebagai tersinkron).
Lyrics loadLyricsFor(String audioPath) {
  try {
    final dot = audioPath.lastIndexOf('.');
    final sep = max(audioPath.lastIndexOf('/'), audioPath.lastIndexOf('\\'));
    final stem = dot > sep ? audioPath.substring(0, dot) : audioPath;
    for (final ext in const ['.lrc', '.LRC', '.txt', '.TXT']) {
      final f = File('$stem$ext');
      if (!f.existsSync()) continue;
      final text = utf8
          .decode(f.readAsBytesSync(), allowMalformed: true)
          .replaceAll('\uFEFF', '');
      final synced = parseLrc(text);
      if (synced.isNotEmpty) return Lyrics(synced);
      final plain = [
        for (final l in text.split(RegExp(r'\r?\n'))) LyricLine(Duration.zero, l.trim()),
      ];
      while (plain.isNotEmpty && plain.last.text.isEmpty) {
        plain.removeLast();
      }
      if (plain.any((l) => l.text.isNotEmpty)) return Lyrics(plain, synced: false);
    }
  } catch (_) {}
  return Lyrics.empty;
}
