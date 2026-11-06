class LyricLine {
  const LyricLine(this.at, this.text);
  final Duration at;
  final String text;
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
