import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' show readMetadata;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:media_kit/media_kit.dart';

import '../data/models/media_entry.dart';

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
    mediaItem.add(item);
  }

  Future<void> setQueue(List<MediaEntry> items, {int index = 0}) async {
    if (items.isEmpty) return;
    _tagPath = null;
    queue.add([
      for (final e in items) MediaItem(id: e.path, title: e.title, album: 'Local library'),
    ]);
    mediaItem.add(queue.value[index]);
    await player.open(
      Playlist([for (final e in items) Media(e.path)], index: index),
      play: true,
    );
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
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    _shuffle = mode;
    await player.setShuffle(mode != AudioServiceShuffleMode.none);
    _broadcast();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    _repeat = mode;
    await player.setPlaylistMode(switch (mode) {
      AudioServiceRepeatMode.none => PlaylistMode.none,
      AudioServiceRepeatMode.one => PlaylistMode.single,
      _ => PlaylistMode.loop,
    });
    _broadcast();
  }
}
