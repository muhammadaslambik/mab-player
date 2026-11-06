import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_metadata_reader/audio_metadata_reader.dart' show readMetadata;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/painting.dart' show Color, HSLColor;
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as pth;

import '../data/models/media_entry.dart';
import 'lyrics.dart';

/// Pemegang player musik. Hidup selama aplikasi jalan, sehingga musik tetap
/// main di background dan tampil di notifikasi / lock-screen.
class MabAudioHandler extends BaseAudioHandler with SeekHandler {
  MabAudioHandler() {
    player.stream.playing.listen((_) => _broadcast());
    player.stream.buffering.listen((_) => _broadcast());
    player.stream.completed.listen((_) => _broadcast());
    player.stream.playlist.listen((pl) {
      _onTrackChanged(pl.index);
      _broadcast();
    });
    player.stream.duration.listen((d) {
      final cur = mediaItem.value;
      if (cur != null && d > Duration.zero) mediaItem.add(cur.copyWith(duration: d));
    });
  }

  final Player player = Player();
  AudioServiceShuffleMode _shuffle = AudioServiceShuffleMode.none;
  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;

  /// Cover tertanam lagu yang sedang diputar (null = pakai gradien).
  final ValueNotifier<Uint8List?> cover = ValueNotifier<Uint8List?>(null);

  /// Warna aksen dari cover (null = warna tema bawaan).
  final ValueNotifier<Color?> accent = ValueNotifier<Color?>(null);

  /// Lirik tersinkron (.lrc di samping file lagu); kosong bila tidak ada.
  final ValueNotifier<List<LyricLine>> lyrics = ValueNotifier<List<LyricLine>>(const []);

  /// Preset equalizer aktif.
  final ValueNotifier<String> eq = ValueNotifier<String>('flat');

  /// Info lagu aktif tanpa emisi berulang (mis. saat durasi diperbarui).
  late final Stream<MediaItem?> trackInfo = mediaItem.distinct(
      (a, b) => a?.id == b?.id && a?.title == b?.title && a?.artist == b?.artist);

  /// Waktu sleep timer berakhir (null = mati).
  final ValueNotifier<DateTime?> sleepAt = ValueNotifier<DateTime?>(null);
  Timer? _sleepTimer;
  String? _tagPath;

  /// Baca tag (judul, artis, album, cover) hanya untuk lagu yang sedang
  /// diputar, supaya scan pustaka tetap ringan dan hanya satu cover di memori.
  void _onTrackChanged(int index) {
    final q = queue.value;
    if (index < 0 || index >= q.length) return;
    final base = q[index];
    if (_tagPath == base.id) return;
    _tagPath = base.id;

    var item = base;
    Uint8List? art;
    try {
      final m = readMetadata(File(base.id), getImage: true);
      final title = m.title?.trim();
      final artist = m.artist?.trim();
      final album = m.album?.trim();
      item = base.copyWith(
        title: (title == null || title.isEmpty) ? base.title : title,
        artist: (artist == null || artist.isEmpty) ? null : artist,
        album: (album == null || album.isEmpty) ? base.album : album,
      );
      if (m.pictures.isNotEmpty) art = m.pictures.first.bytes;
    } catch (_) {
      // Tag tidak terbaca atau format tidak didukung: pakai nama file.
    }
    cover.value = art;
    lyrics.value = _loadLrc(base.id);
    if (art == null) {
      accent.value = null;
    } else {
      _accentOf(art).then((c) {
        if (_tagPath == base.id) accent.value = c;
      });
    }
    mediaItem.add(item);
  }

  List<LyricLine> _loadLrc(String audioPath) {
    try {
      final dot = audioPath.lastIndexOf('.');
      final stem = dot > 0 ? audioPath.substring(0, dot) : audioPath;
      final f = File('$stem.lrc');
      if (!f.existsSync()) return const [];
      return parseLrc(utf8.decode(f.readAsBytesSync(), allowMalformed: true));
    } catch (_) {
      return const [];
    }
  }

  static const _eqPresets = <String, String>{
    'flat': '',
    'bass': 'equalizer=f=60:t=q:w=1:g=6,equalizer=f=170:t=q:w=1:g=3',
    'treble': 'equalizer=f=4000:t=q:w=1:g=4,equalizer=f=10000:t=q:w=1:g=6',
    'vocal': 'equalizer=f=250:t=q:w=1:g=-2,equalizer=f=2000:t=q:w=1:g=4,equalizer=f=4000:t=q:w=1:g=2',
    'loud': 'equalizer=f=60:t=q:w=1:g=5,equalizer=f=1000:t=q:w=1:g=-2,equalizer=f=10000:t=q:w=1:g=5',
  };

  /// Pasang preset equalizer lewat filter audio libmpv. false = gagal.
  Future<bool> setEq(String id) async {
    try {
      final f = _eqPresets[id] ?? '';
      final native = player.platform as dynamic;
      await native.setProperty('af', f.isEmpty ? '' : 'lavfi=[$f]');
      eq.value = id;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Warna dominan ringan: cover dikecilkan ke ~24 px lalu dirata-rata,
  /// piksel yang lebih jenuh diberi bobot lebih besar.
  Future<Color?> _accentOf(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? img;
    try {
      codec = await ui.instantiateImageCodec(bytes, targetWidth: 24);
      img = (await codec.getNextFrame()).image;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      double r = 0, g = 0, b = 0, w = 0;
      var count = 0;
      for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
        if (data.getUint8(i + 3) < 128) continue;
        final pr = data.getUint8(i), pg = data.getUint8(i + 1), pb = data.getUint8(i + 2);
        final hsl = HSLColor.fromColor(Color.fromARGB(255, pr, pg, pb));
        final wt = hsl.saturation * (1 - (2 * hsl.lightness - 1).abs()) + 0.001;
        r += pr * wt;
        g += pg * wt;
        b += pb * wt;
        w += wt;
        count++;
      }
      if (count == 0 || w < 0.05 * count) return null; // hampir abu-abu
      final avg = HSLColor.fromColor(
          Color.fromARGB(255, (r / w).round(), (g / w).round(), (b / w).round()));
      return avg
          .withLightness(0.72)
          .withSaturation(avg.saturation.clamp(0.4, 0.85).toDouble())
          .toColor();
    } catch (_) {
      return null;
    } finally {
      img?.dispose();
      codec?.dispose();
    }
  }

  Future<void> setQueue(List<MediaEntry> items, {int index = 0, bool play = true}) =>
      _openItems([
        for (final e in items) MediaItem(id: e.path, title: e.title, album: 'Local library'),
      ], index, play);

  /// Pulihkan antrean dari penyimpanan (tidak langsung diputar).
  Future<void> restoreQueue(List<String> paths, {int index = 0}) => _openItems([
        for (final p in paths)
          MediaItem(id: p, title: pth.basenameWithoutExtension(p), album: 'Local library'),
      ], index, false);

  Future<void> _openItems(List<MediaItem> items, int index, bool play) async {
    if (items.isEmpty) return;
    _tagPath = null;
    queue.add(items);
    mediaItem.add(items[index]);
    await player.open(
      Playlist([for (final m in items) Media(m.id)], index: index),
      play: play,
    );
  }

  /// Tambahkan lagu ke antrean: [next] = tepat setelah lagu yang sedang main.
  Future<void> enqueue(MediaEntry e, {bool next = false}) async {
    if (queue.value.isEmpty) {
      await setQueue([e]);
      return;
    }
    final oldLen = queue.value.length;
    final cur = player.state.playlist.index;
    final at = next ? min(cur + 1, oldLen) : oldLen;
    final q = [...queue.value]
      ..insert(at, MediaItem(id: e.path, title: e.title, album: 'Local library'));
    queue.add(q);
    await player.add(Media(e.path));
    if (at != oldLen) await player.move(oldLen, at);
  }

  /// Atur sleep timer; null mematikan.
  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    if (d == null) {
      sleepAt.value = null;
      return;
    }
    sleepAt.value = DateTime.now().add(d);
    _sleepTimer = Timer(d, () {
      player.pause();
      sleepAt.value = null;
    });
  }

  void _broadcast() {
    final s = player.state;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        s.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: queue.value.isEmpty
          ? AudioProcessingState.idle
          : s.buffering
              ? AudioProcessingState.buffering
              : s.completed
                  ? AudioProcessingState.completed
                  : AudioProcessingState.ready,
      playing: s.playing,
      updatePosition: s.position,
      speed: s.rate,
      queueIndex: s.playlist.index,
      shuffleMode: _shuffle,
      repeatMode: _repeat,
    ));
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    _broadcast();
  }

  @override
  Future<void> skipToNext() => player.next();
  @override
  Future<void> skipToPrevious() => player.previous();
  @override
  Future<void> skipToQueueItem(int index) => player.jump(index);
  @override
  Future<void> setSpeed(double speed) => player.setRate(speed);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffle = shuffleMode;
    await player.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
    _broadcast();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = repeatMode;
    await player.setPlaylistMode(switch (repeatMode) {
      AudioServiceRepeatMode.none => PlaylistMode.none,
      AudioServiceRepeatMode.one => PlaylistMode.single,
      _ => PlaylistMode.loop,
    });
    _broadcast();
  }
}
