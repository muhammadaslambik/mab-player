enum MediaKind { audio, video }

class MediaEntry {
  const MediaEntry({required this.path, required this.title, required this.kind});

  final String path;
  final String title;
  final MediaKind kind;

  Map<String, dynamic> toJson() => {'path': path, 'title': title, 'kind': kind.name};

  factory MediaEntry.fromJson(Map<String, dynamic> j) => MediaEntry(
        path: j['path'] as String,
        title: j['title'] as String,
        kind: MediaKind.values.byName(j['kind'] as String),
      );
}
