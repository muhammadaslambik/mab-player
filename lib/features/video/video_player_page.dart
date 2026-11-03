import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/format.dart';
import '../../data/models/media_entry.dart';
import '../../data/repositories/history_repo.dart';
import '../../providers.dart';

enum AspectMode {
  fit('Fit', BoxFit.contain, null),
  fill('Fill', BoxFit.cover, null),
  wide('16:9', BoxFit.contain, 16 / 9),
  classic('4:3', BoxFit.contain, 4 / 3),
  stretch('Stretch', BoxFit.fill, null);

  const AspectMode(this.label, this.boxFit, this.ratio);
  final String label;
  final BoxFit boxFit;
  final double? ratio;
}

class VideoPlayerPage extends ConsumerStatefulWidget {
  const VideoPlayerPage({super.key, required this.entry, this.startAt});
  final MediaEntry entry;
  final Duration? startAt;

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  late final HistoryRepo _history;

  Timer? _hideTimer;
  bool _show = true;
  double _speed = 1.0;
  AspectMode _aspect = AspectMode.fit;

  bool get _mobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _history = ref.read(historyProvider);
    ref.read(audioHandlerProvider).pause(); // jangan putar musik di atas video

    // Player dibuat per halaman dan di-dispose saat keluar -> tidak bocor memori.
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(enableHardwareAcceleration: true),
    );

    if (_mobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    WakelockPlus.enable();
    _open();
    _scheduleHide();
  }

  Future<void> _open() async {
    await _player.open(Media(widget.entry.path));
    try {
      final resume = widget.startAt ?? await _history.lastPosition(widget.entry.path);
      if (resume > const Duration(seconds: 5)) {
        await _player.stream.duration.firstWhere((d) => d > Duration.zero);
        await _player.seek(resume);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _history.record(widget.entry, _player.state.position);
    _player.dispose();
    WakelockPlus.disable();
    if (_mobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(const []);
    } else {
      windowManager.setFullScreen(false);
    }
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) setState(() => _show = false);
    });
  }

  void _poke() {
    if (!_show) setState(() => _show = true);
    _scheduleHide();
  }

  void _seekBy(int seconds) {
    _player.seek(_player.state.position + Duration(seconds: seconds));
    _poke();
  }

  Future<void> _toggleFullscreen() async {
    if (_mobile) return;
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
  }

  Future<void> _pickSubtitle() async {
    final r = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt', 'ass'],
    );
    final path = r?.path;
    if (path != null) await _player.setSubtitleTrack(SubtitleTrack.uri(path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _player.playOrPause,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekBy(-10),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekBy(10),
          const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
        },
        child: Focus(
          autofocus: true,
          child: MouseRegion(
            cursor: _show ? SystemMouseCursors.basic : SystemMouseCursors.none,
            onHover: (_) => _poke(),
            child: GestureDetector(
              onTap: () => setState(() => _show = !_show),
              onDoubleTap: _player.playOrPause,
              child: Stack(fit: StackFit.expand, children: [
                Video(
                  controller: _controller,
                  fit: _aspect.boxFit,
                  aspectRatio: _aspect.ratio,
                  controls: NoVideoControls,
                ),
                AnimatedOpacity(
                  opacity: _show ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(ignoring: !_show, child: _overlay(context)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    const shade = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black87, Colors.transparent, Colors.transparent, Colors.black87],
      stops: [0, 0.25, 0.7, 1],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: shade),
      child: SafeArea(
        child: Column(children: [
          Row(children: [
            BackButton(color: Colors.white, onPressed: () => Navigator.maybePop(context)),
            Expanded(
              child: Text(widget.entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            IconButton(
              tooltip: 'Bookmark',
              icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
              onPressed: () {
                _history.addBookmark(widget.entry, _player.state.position);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Bookmark disimpan')));
              },
            ),
            IconButton(
              tooltip: 'Subtitle',
              icon: const Icon(Icons.subtitles_rounded, color: Colors.white),
              onPressed: _pickSubtitle,
            ),
            PopupMenuButton<AspectMode>(
              tooltip: 'Aspect ratio',
              icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
              initialValue: _aspect,
              onSelected: (m) => setState(() => _aspect = m),
              itemBuilder: (_) => [
                for (final m in AspectMode.values)
                  PopupMenuItem(value: m, child: Text(m.label)),
              ],
            ),
            PopupMenuButton<double>(
              tooltip: 'Kecepatan',
              icon: const Icon(Icons.speed_rounded, color: Colors.white),
              initialValue: _speed,
              onSelected: (v) {
                setState(() => _speed = v);
                _player.setRate(v);
              },
              itemBuilder: (_) => [
                for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                  PopupMenuItem(value: s, child: Text('${s}x')),
              ],
            ),
            if (!_mobile)
              IconButton(
                tooltip: 'Layar penuh (F)',
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                onPressed: _toggleFullscreen,
              ),
          ]),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                iconSize: 36,
                color: Colors.white,
                icon: const Icon(Icons.replay_10_rounded),
                onPressed: () => _seekBy(-10)),
            StreamBuilder<bool>(
              stream: _player.stream.playing,
              initialData: _player.state.playing,
              builder: (_, s) => IconButton(
                iconSize: 56,
                color: Colors.white,
                icon: Icon(s.data == true
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded),
                onPressed: () {
                  _player.playOrPause();
                  _poke();
                },
              ),
            ),
            IconButton(
                iconSize: 36,
                color: Colors.white,
                icon: const Icon(Icons.forward_10_rounded),
                onPressed: () => _seekBy(10)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: StreamBuilder<Duration>(
              stream: _player.stream.position,
              initialData: _player.state.position,
              builder: (_, pos) => StreamBuilder<Duration>(
                stream: _player.stream.duration,
                initialData: _player.state.duration,
                builder: (_, dur) {
                  final total = (dur.data ?? Duration.zero).inMilliseconds.toDouble();
                  final cur = (pos.data ?? Duration.zero).inMilliseconds.toDouble();
                  final value = (total <= 0 ? 0.0 : cur.clamp(0.0, total)).toDouble();
                  return Row(children: [
                    Text(fmt(pos.data ?? Duration.zero),
                        style: const TextStyle(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        value: value,
                        max: total <= 0 ? 1.0 : total,
                        onChanged: (v) {
                          _player.seek(Duration(milliseconds: v.round()));
                          _poke();
                        },
                      ),
                    ),
                    Text(fmt(dur.data ?? Duration.zero),
                        style: const TextStyle(color: Colors.white)),
                  ]);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
